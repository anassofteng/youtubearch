import os
import time
from pathlib import Path
import requests
import boto3
from secret_keys import SecretKeys
import subprocess


secret_keys = SecretKeys()

class VideoTranscoder:
    def __init__(self):
        self.s3_client = boto3.client(
            "s3",
            region_name=secret_keys.REGION_NAME,
            aws_access_key_id=secret_keys.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=secret_keys.AWS_SECRET_ACCESS_KEY,
        )


    def _get_content_type(self, file_path: str) -> str:
        if file_path.endswith('.m3u8'):
            return 'application/vnd.apple.mpegurl'
        elif file_path.endswith('.ts'):
            return 'video/MP2T'
        elif file_path.endswith('.mpd'):
            return 'application/dash+xml'
        elif file_path.endswith('.m4s'):
            return 'video/mp4'




    def download_video(self, local_path: str):
        self.s3_client.download_file(
            secret_keys.S3_BUCKET,
            secret_keys.S3_KEY,
            local_path
        )   

    def transcode_video(self, input_path: str, output_path: str):   
    # Create output directory if it doesn't exist
        Path(output_path).mkdir(parents=True, exist_ok=True)
        
        # dash format with proper segment duration
        cmd = [
            "ffmpeg",
            "-i", input_path,
            # Video scaling
            "-filter_complex",
            "[0:v]split=3[v1][v2][v3];"
            "[v1]scale=640:360:flags=fast_bilinear[360p];"
            "[v2]scale=1280:720:flags=fast_bilinear[720p];"
            "[v3]scale=1920:1080:flags=fast_bilinear[1080p]",
            
            # Common video settings
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-profile:v", "high",
            "-level:v", "4.1",
            "-sc_threshold", "0",
            
            # 360p
            "-map", "[360p]",
            "-b:v:0", "1000k",
            "-maxrate:v:0", "1200k",
            "-bufsize:v:0", "2000k",
            
            # 720p
            "-map", "[720p]",
            "-b:v:1", "4000k",
            "-maxrate:v:1", "4800k",
            "-bufsize:v:1", "8000k",
            
            # 1080p
            "-map", "[1080p]",
            "-b:v:2", "8000k",
            "-maxrate:v:2", "9600k",
            "-bufsize:v:2", "16000k",
            
            # Audio settings (explicit configuration)
            "-map", "0:a",
            "-c:a", "aac",
            "-b:a", "128k",
            "-ar", "48000",
            "-ac", "2",
            
            # DASH specific settings - CRITICAL FIXES
            "-f", "dash",
            "-seg_duration", "2",  # 2-second segments
            "-window_size", "10",  # Keep 10 segments in manifest (was 5)
            "-extra_window_size", "5",
            "-remove_at_exit", "0",
            "-use_timeline", "1",
            "-use_template", "1",
            "-adaptation_sets", "id=0,streams=v id=1,streams=a",
            "-init_seg_name", "init_$RepresentationID$.$ext$",
            "-media_seg_name", "chunk_$RepresentationID$_$Number%05d$.$ext$",
            
            # GOP settings aligned with segment duration
            "-g", "48",  # 2 seconds at 24fps, or adjust based on your video fps
            "-keyint_min", "48",
            
            # Output path
            f"{output_path}/manifest.mpd",
        ]
        
        # Print the command for debugging
        print("Running FFmpeg command:")
        print(" ".join(cmd))
        
        process = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True
        )
        
        if process.returncode != 0:
            print("FFmpeg stderr:", process.stderr)
            raise Exception(f"Error during transcoding process: {process.stderr}")
        
        print("FFmpeg stdout:", process.stdout)
        
    def upload_files(self, prefix:str,local_dir):
        for root, _, files in os.walk(local_dir):
            for file in files:
                local_path = os.path.join(root, file)
                s3_key = f"{prefix}/{os.path.relpath(local_path, local_dir)}"
                self.s3_client.upload_file(
                    local_path,
                    secret_keys.S3_PROCESSED_VIDEOS_BUCKET,
                    s3_key,
                    ExtraArgs = {
                        # 'ACL' : 'public-read',
                        'ContentType' : self._get_content_type(local_path)

                    }
                )


    def process_video(self):
        work_dir = Path("/tmp/workspace")
        work_dir.mkdir(exist_ok = True)
        input_path = work_dir /  "input.mp4"
        output_path = work_dir / "output"
        output_path.mkdir(exist_ok = True)
        try:
            self.download_video(input_path)
            print("✅ Download complete")
            self.transcode_video(str(input_path), str(output_path))
            time.sleep(5)
            print("✅ Transcoding complete")
            print("\n📂 Files in output directory:")
            import os
            for item in os.listdir(str(output_path)):
                full_path = os.path.join(str(output_path), item)
                if os.path.isfile(full_path):
                   print(f"  {item} - {os.path.getsize(full_path)} bytes")
                else:
                   print(f"  {item}/ (directory)")
            self.upload_files(secret_keys.S3_KEY, str(output_path))
            self.update_video()
            print("✅ Upload complete")
            print("✅ Processing completed successfully!")


            
            time.sleep(30)

        except Exception as e:
             print(f"❌ Error: {e}")
             import traceback
             traceback.print_exc()
             raise 
         

        finally:
            time.sleep(10)
            if input_path.exists():
                input_path.unlink()
            if output_path.exists():
                import shutil
                shutil.rmtree(str(output_path))

    def update_video(self):
        video_id = os.environ.get("VIDEO_ID")

        if not video_id:
            raise Exception("VIDEO_ID not found in environment")
        
        url = f"{secret_keys.BACKEND_URL}/videos/{video_id}"
        print("Calling backend URL:", url)

        response = requests.put(
        url,
        timeout=10
        )

        print("Status code:", response.status_code)
        print("Raw response:", response.text)

        if not response.headers.get("content-type", "").startswith("application/json"):
            raise Exception("Backend did not return JSON")

        return response.json()



                                      

VideoTranscoder().process_video()



    
                  





# hls format  
        # cmd = [
        #     "ffmpeg",
        #     "-i",
        #     input_path,
        #     "-filter_complex",
        #     "[0:v]split=3[v1][v2][v3];"
        #     "[v1]scale=640:360:flags=fast_bilinear[360p];"
        #     "[v2]scale=1280:720:flags=fast_bilinear[720p];"
        #     "[v3]scale=1920:1080:flags=fast_bilinear[1080p]",
        #     "-map",
        #     "[360p]",
        #     "-map",
        #     "[720p]",
        #     "-map",
        #     "[1080p]",
        #     "-c:v",
        #     "libx264",
        #     "-preset",
        #     "veryfast",
        #     "-profile:v",
        #     "high",
        #     "-level:v",
        #     "4.1",
        #     "-g",
        #     "48",
        #     "-keyint_min",
        #     "48",
        #     "-sc_threshold",
        #     "0",
        #     "-b:v:0",
        #     "1000k",
        #     "-b:v:1",
        #     "4000k",
        #     "-b:v:2",
        #     "8000k",
        #     "-f",
        #     "hls",
        #     "-hls_time",
        #     "6",
        #     "-hls_playlist_type",
        #     "vod",
        #     "-hls_flags",
        #     "independent_segments",
        #     "-hls_segment_type",
        #     "mpegts",
        #     "-hls_list_size",
        #     "0",
        #     "-master_pl_name",
        #     "master.m3u8",
        #     "-var_stream_map",
        #     "v:0 v:1 v:2",
        #     "-hls_segment_filename",
        #     f"{output_path}/%v/segment_%03d.ts",
        #     f"{output_path}/%v/playlist.m3u8",
        # ]

#         import os
# import time
# from pathlib import Path

# import boto3
# from secret_keys import SecretKeys
# import subprocess


# secret_keys = SecretKeys()

# class VideoTranscoder:
#     def __init__(self):
#         self.s3_client = boto3.client(
#             "s3",
#             region_name=secret_keys.REGION_NAME,
#             aws_access_key_id=secret_keys.AWS_ACCESS_KEY_ID,
#             aws_secret_access_key=secret_keys.AWS_SECRET_ACCESS_KEY,
#         )


#     def _get_content_type(self, file_path: str) -> str:
#         if file_path.endswith('.m3u8'):
#             return 'application/vnd.apple.mpegurl'
#         elif file_path.endswith('.ts'):
#             return 'video/MP2T'
#         elif file_path.endswith('.mpd'):
#             return 'application/dash+xml'
#         elif file_path.endswith('.m4s'):
#             return 'video/mp4'




#     def download_video(self, local_path: str):
#         self.s3_client.download_file(
#             secret_keys.S3_BUCKET,
#             secret_keys.S3_KEY,
#             local_path
#         )   

#     def transcode_video(self, input_path: str, output_path: str):   
        

# # dash format
#         cmd = [
#             "ffmpeg",
#             "-i",
#             input_path,
#             "-filter_complex",
#             "[0:v]split=3[v1][v2][v3];"
#             "[v1]scale=640:360:flags=fast_bilinear[360p];"
#             "[v2]scale=1280:720:flags=fast_bilinear[720p];"
#             "[v3]scale=1920:1080:flags=fast_bilinear[1080p]",
#             # 360p video stream
#             "-map",
#             "[360p]",
#             "-c:v:0",
#             "libx264",
#             "-b:v:0",
#             "1000k",
#             "-preset",
#             "veryfast",
#             "-profile:v",
#             "high",
#             "-level:v",
#             "4.1",
#             "-g",
#             "48",
#             "-keyint_min",
#             "48",
#             # 720p video stream
#             "-map",
#             "[720p]",
#             "-c:v:1",
#             "libx264",
#             "-b:v:1",
#             "4000k",
#             "-preset",
#             "veryfast",
#             "-profile:v",
#             "high",
#             "-level:v",
#             "4.1",
#             "-g",
#             "48",
#             "-keyint_min",
#             "48",
#             # 1080p video stream
#             "-map",
#             "[1080p]",
#             "-c:v:2",
#             "libx264",
#             "-b:v:2",
#             "8000k",
#             "-preset",
#             "veryfast",
#             "-profile:v",
#             "high",
#             "-level:v",
#             "4.1",
#             "-g",
#             "48",
#             "-keyint_min",
#             "48",
#             # Audio stream
#             "-map",
#             "0:a",
#             "-c:a",
#             "aac",
#             "-b:a",
#             "128k",
#             # DASH specific settings
#             "-use_timeline",
#             "1",
#             "-use_template",
#             "1",
#             "-window_size",
#             "5",
#             "-adaptation_sets",
#             "id=0,streams=v id=1,streams=a",
#             "-f",
#             "dash",
#             f"{output_path}/manifest.mpd",
#         ]

#         process = subprocess.run(cmd)

#         if process.returncode != 0:
#             raise Exception("Error during transcoding process")
        
#     def upload_files(self, prefix:str,local_dir):
#         for root, _, files in os.walk(local_dir):
#             for file in files:
#                 local_path = os.path.join(root, file)
#                 s3_key = f"{prefix}/{os.path.relpath(local_path, local_dir)}"
#                 self.s3_client.upload_file(
#                     local_path,
#                     secret_keys.S3_PROCESSED_VIDEOS_BUCKET,
#                     s3_key,
#                     ExtraArgs = {
#                         'ACL' : 'public-read',
#                         'ContentType' : self._get_content_type(local_path)

#                     }
#                 )


#     def process_video(self):
#         work_dir = Path("/tmp/workspace")
#         work_dir.mkdir(exist_ok = True)
#         input_path = work_dir /  "input.mp4"
#         output_path = work_dir / "output"
#         output_path.mkdir(exist_ok = True)
#         try:
#             self.download_video(input_path)
#             print("✅ Download complete")
#             self.transcode_video(str(input_path), str(output_path))
#             time.sleep(5)
#             print("✅ Transcoding complete")
#             print("\n📂 Files in output directory:")
#             import os
#             for item in os.listdir(str(output_path)):
#                 full_path = os.path.join(str(output_path), item)
#                 if os.path.isfile(full_path):
#                    print(f"  {item} - {os.path.getsize(full_path)} bytes")
#                 else:
#                    print(f"  {item}/ (directory)")
#             self.upload_files(secret_keys.S3_KEY, str(output_path))
#             print("✅ Upload complete")
#             print("✅ Processing completed successfully!")


            
#             time.sleep(30)

#         except Exception as e:
#              print(f"❌ Error: {e}")
#              import traceback
#              traceback.print_exc()
#              raise 
         

#         finally:
#             time.sleep(10)
#             if input_path.exists():
#                 input_path.unlink()
#             if output_path.exists():
#                 import shutil
#                 shutil.rmtree(str(output_path))                  

# VideoTranscoder().process_video()



