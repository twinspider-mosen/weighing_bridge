import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weighing_bridge/model/user_model.dart';
import 'package:weighing_bridge/services/api_service.dart';
import 'package:weighing_bridge/services/session_service.dart';
import 'package:weighing_bridge/views/weighing_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _subdomainController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showLoginForm = false;

  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSubdomain();
  }

  Future<void> _loadSavedSubdomain() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSubdomain = prefs.getString('active_subdomain');
    if (savedSubdomain != null && savedSubdomain.isNotEmpty) {
      setState(() {
        _subdomainController.text = savedSubdomain;
        _showLoginForm = true;
      });
    }
  }

  Future<void> _submitSubdomain() async {
    if (_subdomainController.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final response = await _apiService.verifySubdomain(
          subdomain: _subdomainController.text.trim(),
        );

        // We consider success if statusCode is 200, else we show error
        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'active_subdomain',
            _subdomainController.text.trim(),
          );
          if (!mounted) return;
          setState(() {
            _showLoginForm = true;
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid subdomain or server error')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying subdomain: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid subdomain')),
      );
    }
  }

  Future<void> _submitLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _subdomainController.text.trim(),
      );
      log(response.toString());
      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? {};
        final user = UserModel(
          id: responseData['email'] ?? _emailController.text.trim(),
          name: responseData['username'] ?? 'User',
          email: responseData['email'] ?? _emailController.text.trim(),
          company: responseData['company_name'] ?? 'Company',
          token: responseData['token'] ?? '',
        );

        await SessionService.saveUser(user);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WeighingScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check credentials.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging in: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _subdomainController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.greenAccent),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.greenAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F25),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.login, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Text(
              'LOGIN',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF1A1F25), Color(0xFF0A0E12)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F25).withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !_showLoginForm
                    ? _buildSubdomainForm()
                    : _buildLoginForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubdomainForm() {
    return Column(
      key: const ValueKey('subdomain_form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome to\nWeighing Bridge',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your workspace subdomain to continue',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _subdomainController,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _inputDecoration('Subdomain', Icons.domain),
          onSubmitted: (_) => _submitSubdomain(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _submitSubdomain,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'CONTINUE',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login_form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.greenAccent),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('active_subdomain');
                setState(() {
                  _showLoginForm = false;
                });
              },
            ),
            Expanded(
              child: Text(
                '${_subdomainController.text}.weighing.com',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.greenAccent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Sign In',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your credentials to access your dashboard',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _inputDecoration('Email', Icons.email),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: _inputDecoration('Password', Icons.lock),
          obscureText: true,
          onSubmitted: (_) => _submitLogin(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _submitLogin,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'LOGIN',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ],
    );
  }
}
