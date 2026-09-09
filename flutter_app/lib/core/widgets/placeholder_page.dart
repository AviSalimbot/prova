import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A2433),
        ),
      ),
    );
  }
}