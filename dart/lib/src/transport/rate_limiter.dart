import '../../sentry.dart';
import '../transport/rate_limit_parser.dart';
import 'rate_limit.dart';
import 'data_category.dart';
import '../client_reports/discard_reason.dart';

/// Controls retry limits on different category types sent to Sentry.
class RateLimiter {
  RateLimiter(this._options);

  final SentryOptions _options;
  final _rateLimitedUntil = <DataCategory, DateTime>{};

  /// Filter out envelopes that are rate limited.
  SentryEnvelope? filter(SentryEnvelope envelope) {
    // Optimize for/No allocations if no items are under 429
    List<SentryEnvelopeItem>? dropItems;
    for (final item in envelope.items) {
      // using the raw value of the enum to not expose SentryEnvelopeItemType
      if (_isRetryAfter(item.header.type)) {
        dropItems ??= [];
        dropItems.add(item);

        _options.recorder.recordLostEvent(
          DiscardReason.rateLimitBackoff,
          DataCategory.fromItemType(item.header.type),
        );

        final originalObject = item.originalObject;
        if (originalObject is SentryTransaction) {
          _options.recorder.recordLostEvent(
            DiscardReason.rateLimitBackoff,
            DataCategory.span,
            count: originalObject.spans.length + 1,
          );
        }
      }
    }

    if (dropItems != null) {
      // Need a new envelope
      final toSend = <SentryEnvelopeItem>[];
      for (final item in envelope.items) {
        if (!dropItems.contains(item)) {
          toSend.add(item);
        }
      }

      // no reason to continue
      if (toSend.isEmpty) {
        return null;
      }

      return SentryEnvelope(envelope.header, toSend);
    } else {
      return envelope;
    }
  }

  /// Update rate limited categories
  void updateRetryAfterLimits(
      String? sentryRateLimitHeader, String? retryAfterHeader, int errorCode) {
    final currentDateTime = _options.clock().millisecondsSinceEpoch;
    var rateLimits = <RateLimit>[];

    if (sentryRateLimitHeader != null) {
      rateLimits =
          RateLimitParser(sentryRateLimitHeader).parseRateLimitHeader();
    } else if (errorCode == 429) {
      rateLimits = RateLimitParser(retryAfterHeader).parseRetryAfterHeader();
    }

    for (final rateLimit in rateLimits) {
      if (rateLimit.category == DataCategory.metricBucket &&
          rateLimit.namespaces.isNotEmpty &&
          !rateLimit.namespaces.contains('custom')) {
        continue;
      }
      _applyRetryAfterOnlyIfLonger(
        rateLimit.category,
        DateTime.fromMillisecondsSinceEpoch(
            currentDateTime + rateLimit.duration.inMilliseconds),
      );
    }
  }

  // Private

  bool _isRetryAfter(String itemType) {
    final dataCategory = DataCategory.fromItemType(itemType);
    final currentDate = DateTime.fromMillisecondsSinceEpoch(
        _options.clock().millisecondsSinceEpoch);

    // check all categories
    final dateAllCategories = _rateLimitedUntil[DataCategory.all];
    if (dateAllCategories != null) {
      if (!currentDate.isAfter(dateAllCategories)) {
        return true;
      }
    }

    // Unknown should not be rate limited
    if (DataCategory.unknown == dataCategory) {
      return false;
    }

    // check for specific dataCategory
    final dateCategory = _rateLimitedUntil[dataCategory];
    if (dateCategory != null) {
      return !currentDate.isAfter(dateCategory);
    }

    return false;
  }

  void _applyRetryAfterOnlyIfLonger(DataCategory dataCategory, DateTime date) {
    final oldDate = _rateLimitedUntil[dataCategory];

    // only overwrite its previous date if the limit is even longer
    if (oldDate == null || date.isAfter(oldDate)) {
      _rateLimitedUntil[dataCategory] = date;
    }
  }
}
