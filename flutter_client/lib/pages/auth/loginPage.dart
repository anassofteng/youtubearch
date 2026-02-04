import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_client/cubits/auth/auth_cubit.dart';
import 'package:flutter_client/pages/auth/home/homepage.dart';
import 'package:flutter_client/pages/auth/signup_page.dart';
import 'package:flutter_client/services/auth_service.dart';

class Loginpage extends StatefulWidget {
  static route() => MaterialPageRoute(builder: (context) => Loginpage());
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final authServices = AuthService();

  void loginuser() async {
    if (_formKey.currentState!.validate()) {
      //perform signup
      context.read<AuthCubit>().loginUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _emailController.dispose();
    _passwordController.dispose();
    _formKey.currentState!.validate();
    super.dispose();
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  void login() {
    if (_formKey.currentState!.validate()) {
      //perform signup
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sign in.")),
      body: Form(
        key: _formKey,
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            // TODO: implement listener
            if (state is AuthSignupSuccess) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
              Navigator.push(
                context,
               HomePage.route(),
              );
            } else if (state is AuthError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          builder: (context, state) {
            if (state is AuthLoading) {
              return Center(child: CircularProgressIndicator.adaptive());
            }
            return Padding(
              padding: EdgeInsets.all(15),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Sign in",
                      style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 50),
                    TextFormField(
                      validator: (value) =>
                          (value == null || value.isEmpty || value.trim().isEmpty)
                          ? "Please enter a valid email"
                          : null,
                      controller: _emailController,
                      decoration: InputDecoration(hint: Text("Email")),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      obscureText: true,
                      validator: (value) => (value == null || value.length < 6)
                          ? "Password must be at least 6 characters long"
                          : null,
                      controller: _passwordController,
                      decoration: InputDecoration(hint: Text("Password")),
                    ),
                
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: loginuser,
                      child: Text(
                        "Login",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                    ),
                
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, SignupPage.route());
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          style: Theme.of(context).textTheme.titleMedium,
                          children: [
                            TextSpan(
                              text: 'SignUp',
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
            );
          },
        ),
      ),
    );
  }
}
