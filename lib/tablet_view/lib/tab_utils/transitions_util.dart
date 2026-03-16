import 'package:flutter/material.dart';

class SlideRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideRightRoute({required this.page, RouteSettings? settings})
    : super(
        settings: settings ?? RouteSettings(name: page.runtimeType.toString()),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
      );
}

class SlideLeftRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideLeftRoute({required this.page, RouteSettings? settings})
    : super(
        settings: settings ?? RouteSettings(name: page.runtimeType.toString()),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
      );
}

class SlideTopRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideTopRoute({required this.page, RouteSettings? settings})
    : super(
        settings: settings ?? RouteSettings(name: page.runtimeType.toString()),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
      );
}

class SlideBottomRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideBottomRoute({required this.page, RouteSettings? settings})
    : super(
        settings: settings ?? RouteSettings(name: page.runtimeType.toString()),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
      );
}

class ScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  ScaleRoute({required this.page, RouteSettings? settings})
    : super(
        settings: settings ?? RouteSettings(name: page.runtimeType.toString()),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) => ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
              ),
              child: child,
            ),
      );
}

class SizeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SizeRoute({required this.page, RouteSettings? settings})
    : super(
        settings: settings ?? RouteSettings(name: page.runtimeType.toString()),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) => Align(
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
      );
}

class FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeRoute({required this.page, RouteSettings? settings})
    : super(
        settings: settings ?? RouteSettings(name: page.runtimeType.toString()),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
      );
}
