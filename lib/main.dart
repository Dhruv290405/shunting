import 'package:flutter/material.dart';
import 'dart:async';
import 'app.dart';

void main() {
  runZonedGuarded(
    () => runApp(const ShuntingApp()),
    (error, stack) => debugPrint('Uncaught error: $error\n$stack'),
  );
}