import 'dart:async';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'native_app_start.dart';
import 'native_frames.dart';
import 'method_channel_helper.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_invoker.dart';
import 'sentry_safe_method_channel.dart';

/// Provide typed methods to access native layer via MethodChannel.
@internal
class SentryNativeChannel
    with SentryNativeSafeInvoker
    implements SentryNativeBinding {
  @override
  final SentryFlutterOptions options;

  final SentrySafeMethodChannel _channel;

  SentryNativeChannel(this.options, MethodChannel channel)
      : _channel = SentrySafeMethodChannel(channel, options);

  @override
  Future<void> init(SentryFlutterOptions options) async {
    assert(this.options == options);
    return _channel.invokeMethod('initNativeSdk', <String, dynamic>{
      'dsn': options.dsn,
      'debug': options.debug,
      'environment': options.environment,
      'release': options.release,
      'enableAutoSessionTracking': options.enableAutoSessionTracking,
      'enableNativeCrashHandling': options.enableNativeCrashHandling,
      'attachStacktrace': options.attachStacktrace,
      'attachThreads': options.attachThreads,
      'autoSessionTrackingIntervalMillis':
          options.autoSessionTrackingInterval.inMilliseconds,
      'dist': options.dist,
      'integrations': options.sdk.integrations,
      'packages':
          options.sdk.packages.map((e) => e.toJson()).toList(growable: false),
      'diagnosticLevel': options.diagnosticLevel.name,
      'maxBreadcrumbs': options.maxBreadcrumbs,
      'anrEnabled': options.anrEnabled,
      'anrTimeoutIntervalMillis': options.anrTimeoutInterval.inMilliseconds,
      'enableAutoNativeBreadcrumbs': options.enableAutoNativeBreadcrumbs,
      'maxCacheItems': options.maxCacheItems,
      'sendDefaultPii': options.sendDefaultPii,
      'enableWatchdogTerminationTracking':
          options.enableWatchdogTerminationTracking,
      'enableNdkScopeSync': options.enableNdkScopeSync,
      'enableAutoPerformanceTracing': options.enableAutoPerformanceTracing,
      'sendClientReports': options.sendClientReports,
      'proguardUuid': options.proguardUuid,
      'maxAttachmentSize': options.maxAttachmentSize,
      'recordHttpBreadcrumbs': options.recordHttpBreadcrumbs,
      'captureFailedRequests': options.captureFailedRequests,
      'enableAppHangTracking': options.enableAppHangTracking,
      'connectionTimeoutMillis': options.connectionTimeout.inMilliseconds,
      'readTimeoutMillis': options.readTimeout.inMilliseconds,
      'appHangTimeoutIntervalMillis':
          options.appHangTimeoutInterval.inMilliseconds,
    });
  }

  @override
  Future<void> close() async => _channel.invokeMethod('closeNativeSdk');

  @override
  Future<NativeAppStart?> fetchNativeAppStart() async {
    final json =
        await _channel.invokeMapMethod<String, dynamic>('fetchNativeAppStart');
    return (json != null) ? NativeAppStart.fromJson(json) : null;
  }

  @override
  Future<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    return _channel.invokeMethod(
        'captureEnvelope', [envelopeData, containsUnhandledException]);
  }

  @override
  Future<Map<String, dynamic>?> loadContexts() =>
      _channel.invokeMapMethod<String, dynamic>('loadContexts');

  @override
  Future<void> beginNativeFrames() =>
      _channel.invokeMethod('beginNativeFrames');

  @override
  Future<NativeFrames?> endNativeFrames(SentryId id) async {
    final json = await _channel.invokeMapMethod<String, dynamic>(
        'endNativeFrames', {'id': id.toString()});
    return (json != null) ? NativeFrames.fromJson(json) : null;
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    final normalizedUser = user?.copyWith(
      data: MethodChannelHelper.normalizeMap(user.data),
    );
    await _channel.invokeMethod(
      'setUser',
      {'user': normalizedUser?.toJson()},
    );
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    final normalizedBreadcrumb = breadcrumb.copyWith(
      data: MethodChannelHelper.normalizeMap(breadcrumb.data),
    );
    await _channel.invokeMethod(
      'addBreadcrumb',
      {'breadcrumb': normalizedBreadcrumb.toJson()},
    );
  }

  @override
  Future<void> clearBreadcrumbs() => _channel.invokeMethod('clearBreadcrumbs');

  @override
  Future<void> setContexts(String key, dynamic value) => _channel.invokeMethod(
        'setContexts',
        {'key': key, 'value': MethodChannelHelper.normalize(value)},
      );

  @override
  Future<void> removeContexts(String key) =>
      _channel.invokeMethod('removeContexts', {'key': key});

  @override
  Future<void> setExtra(String key, dynamic value) => _channel.invokeMethod(
        'setExtra',
        {'key': key, 'value': MethodChannelHelper.normalize(value)},
      );

  @override
  Future<void> removeExtra(String key) =>
      _channel.invokeMethod('removeExtra', {'key': key});

  @override
  Future<void> setTag(String key, String value) =>
      _channel.invokeMethod('setTag', {'key': key, 'value': value});

  @override
  Future<void> removeTag(String key) =>
      _channel.invokeMethod('removeTag', {'key': key});

  @override
  int? startProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  Future<void> discardProfiler(SentryId traceId) =>
      _channel.invokeMethod('discardProfiler', traceId.toString());

  @override
  Future<Map<String, dynamic>?> collectProfile(
          SentryId traceId, int startTimeNs, int endTimeNs) =>
      _channel.invokeMapMethod<String, dynamic>('collectProfile', {
        'traceId': traceId.toString(),
        'startTime': startTimeNs,
        'endTime': endTimeNs,
      });

  @override
  Future<List<DebugImage>?> loadDebugImages() =>
      tryCatchAsync('loadDebugImages', () async {
        final images = await _channel
            .invokeListMethod<Map<dynamic, dynamic>>('loadImageList');
        return images
            ?.map((e) => e.cast<String, dynamic>())
            .map(DebugImage.fromJson)
            .toList();
      });

  @override
  Future<int?> displayRefreshRate() =>
      _channel.invokeMethod('displayRefreshRate');

  @override
  Future<void> pauseAppHangTracking() =>
      _channel.invokeMethod('pauseAppHangTracking');

  @override
  Future<void> resumeAppHangTracking() =>
      _channel.invokeMethod('resumeAppHangTracking');
}
