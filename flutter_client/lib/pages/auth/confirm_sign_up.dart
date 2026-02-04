import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_client/cubits/auth/auth_cubit.dart';
import 'package:flutter_client/pages/auth/loginPage.dart';
import 'package:flutter_client/services/auth_service.dart';

class ConfirmSignupPage extends StatefulWidget {
  final String email;
  static route(String email) =>
      MaterialPageRoute(builder: (context) => ConfirmSignupPage(email: email));
  const ConfirmSignupPage({super.key, required this.email});

  @override
  State<ConfirmSignupPage> createState() => _ConfirmSignupPageState();
}

class _ConfirmSignupPageState extends State<ConfirmSignupPage> {
  late final _emailController;

  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  @override
  void initState() {
    _emailController.text = TextEditingController(text: widget.email);
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _emailController.dispose();

    _otpController.dispose();
    _formKey.currentState!.validate();

    super.dispose();
  }

  void confirmSignUp() async {
    if (_formKey.currentState!.validate()) {
      //perform signup
      context.read<AuthCubit>().confirmSignUp(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text("Confirm email")),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthConfirmSuccess) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            Navigator.push(context, Loginpage.route());
          }
          else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if(state is AuthLoading){
            return Center(child: CircularProgressIndicator.adaptive(),);
          }
          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Confirm email",
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 50),
                    TextFormField(
                      controller: _otpController,
                      // decoration: InputDecoration(hint: Text("Name")),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.trim().isEmpty) {
                          return "Please enter a valid email";
                        }
                        return null;
                      },
                      controller: _emailController,
                      decoration: InputDecoration(hint: Text("Email")),
                    ),
                    SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: confirmSignUp,
                      child: Text(
                        "Confirm",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, Loginpage.route());
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Resend OTP? ',
                          style: Theme.of(context).textTheme.titleMedium,
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
