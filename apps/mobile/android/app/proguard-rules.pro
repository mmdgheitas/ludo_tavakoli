# Flutter entry points and generated plugins are loaded reflectively.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Preserve DTO field annotations used by marketplace SDK adapters.
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault,Signature
