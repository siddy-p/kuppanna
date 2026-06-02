import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Data model returned by the delivery quote endpoint.
class DeliveryQuote {
  final String quoteId;
  final int fee; // in minor units (pence)
  final String currency;
  final String? expiresAt; // ISO timestamp
  final int? etaSeconds;

  const DeliveryQuote({
    required this.quoteId,
    required this.fee,
    required this.currency,
    this.expiresAt,
    this.etaSeconds,
  });

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    return DeliveryQuote(
      quoteId:    json['quote_id'] as String,
      fee:        (json['fee'] as num?)?.toInt() ?? 0,
      currency:   json['currency'] as String? ?? 'GBP',
      expiresAt:  json['expires_at'] as String?,
      etaSeconds: (json['eta_seconds'] as num?)?.toInt(),
    );
  }

  /// Fee formatted as a human-readable string e.g. "£4.99"
  String get formattedFee {
    final symbol = currency == 'GBP' ? '£' : (currency == 'USD' ? '\$' : currency);
    return '$symbol${(fee / 100).toStringAsFixed(2)}';
  }

  /// ETA formatted as "~12 min"
  String get formattedEta {
    if (etaSeconds == null) return 'Unknown ETA';
    final minutes = (etaSeconds! / 60).round();
    return '~$minutes min';
  }
}

/// Data model returned by the create-delivery endpoint.
class DeliveryOrder {
  final String orderId;
  final String deliveryId;
  final String? trackingUrl;
  final String status;

  const DeliveryOrder({
    required this.orderId,
    required this.deliveryId,
    this.trackingUrl,
    required this.status,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      orderId:     json['order_id'] as String,
      deliveryId:  json['delivery_id'] as String,
      trackingUrl: json['tracking_url'] as String?,
      status:      json['status'] as String? ?? 'pending',
    );
  }
}

/// Order status from the polling endpoint.
class OrderStatus {
  final String orderId;
  final String deliveryId;
  final String status;
  final String? trackingUrl;

  const OrderStatus({
    required this.orderId,
    required this.deliveryId,
    required this.status,
    this.trackingUrl,
  });

  factory OrderStatus.fromJson(Map<String, dynamic> json) {
    return OrderStatus(
      orderId:     json['order_id'] as String? ?? '',
      deliveryId:  json['delivery_id'] as String? ?? '',
      status:      json['status'] as String? ?? 'pending',
      trackingUrl: json['tracking_url'] as String?,
    );
  }
}

/// Service that calls the Kuppanna Node.js backend.
class ApiService {
  static final _client = http.Client();

  static Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Fetch a delivery quote from the backend.
  static Future<DeliveryQuote> fetchQuote({
    required String pickupAddress,
    required String dropoffAddress,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
  }) async {
    final body = <String, dynamic>{
      'pickup_address':  pickupAddress,
      'dropoff_address': dropoffAddress,
    };
    if (pickupLat != null)  body['pickup_lat']  = pickupLat;
    if (pickupLng != null)  body['pickup_lng']  = pickupLng;
    if (dropoffLat != null) body['dropoff_lat'] = dropoffLat;
    if (dropoffLng != null) body['dropoff_lng'] = dropoffLng;

    final response = await _client
        .post(_uri('/api/delivery-quote'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        data['error'] as String? ?? 'Failed to fetch quote',
        data['detail'],
      );
    }
    return DeliveryQuote.fromJson(data);
  }

  /// Create a delivery with a validated quote.
  static Future<DeliveryOrder> createDelivery({
    required String quoteId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? pickupAddress,
    String? dropoffAddress,
    int? feeAmount,
    String? feeCurrency,
  }) async {
    final body = <String, dynamic>{
      'quote_id':       quoteId,
      'customer_name':  customerName,
      'customer_phone': customerPhone,
      if (customerEmail  != null) 'customer_email':  customerEmail, // ignore: use_null_aware_elements
      if (pickupAddress  != null) 'pickup_address':  pickupAddress, // ignore: use_null_aware_elements
      if (dropoffAddress != null) 'dropoff_address': dropoffAddress, // ignore: use_null_aware_elements
      if (feeAmount      != null) 'fee_amount':      feeAmount, // ignore: use_null_aware_elements
      if (feeCurrency    != null) 'fee_currency':    feeCurrency, // ignore: use_null_aware_elements
    };

    final response = await _client
        .post(_uri('/api/create-delivery'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw ApiException(
        response.statusCode,
        data['error'] as String? ?? 'Failed to create delivery',
        data['detail'],
      );
    }
    return DeliveryOrder.fromJson(data);
  }

  /// Poll order status by delivery_id or order_id.
  static Future<OrderStatus> getOrderStatus(String id) async {
    final response = await _client
        .get(_uri('/api/order/$id'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        data['error'] as String? ?? 'Order not found',
        null,
      );
    }
    return OrderStatus.fromJson(data);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic detail;

  const ApiException(this.statusCode, this.message, this.detail);

  @override
  String toString() => 'ApiException($statusCode): $message — $detail';
}
