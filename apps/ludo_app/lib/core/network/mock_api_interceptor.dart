import 'package:dio/dio.dart';

/// In-memory mobile API used only when `USE_MOCK_DATA=true` is supplied at
/// compile time. It never changes or comments out production repositories.
class MockApiInterceptor extends Interceptor {
  MockApiInterceptor();

  final Map<String, dynamic> _user = {
    'id': '10000000-0000-4000-8000-000000000001',
    'username': 'بازیکن_آزمایشی',
    'email': 'demo@manche.local',
    'avatarUrl': null,
    'coinBalance': 5000,
    'fattahBalance': 3,
    'vipExpiresAt': null,
    'role': 'PLAYER',
    'status': 'ACTIVE',
    'createdAt': '2026-01-01T00:00:00.000Z',
  };

  final List<Map<String, dynamic>> _items = [
    {
      'id': '20000000-0000-4000-8000-000000000001',
      'sku': 'skin.turquoise',
      'nameFa': 'مهره فیروزه‌ای',
      'descriptionFa': 'پوسته آزمایشی مهره‌ها',
      'type': 'PIECE_SKIN',
      'coinPrice': 1200,
      'realPriceIrr': null,
      'metadata': {'color': '#2FC8B3'},
    },
    {
      'id': '20000000-0000-4000-8000-000000000002',
      'sku': 'avatar.pahlevan',
      'nameFa': 'آواتار پهلوان',
      'descriptionFa': 'آواتار آزمایشی پروفایل',
      'type': 'AVATAR',
      'coinPrice': 900,
      'realPriceIrr': null,
      'metadata': null,
    },
    {
      'id': '20000000-0000-4000-8000-000000000003',
      'sku': 'fattah.single',
      'nameFa': 'موشک فتاح',
      'descriptionFa': 'یک آیتم مصرفی آزمایشی',
      'type': 'FATTAH',
      'coinPrice': 600,
      'realPriceIrr': null,
      'metadata': null,
    },
  ];

  final List<Map<String, dynamic>> _inventory = [];
  final List<Map<String, dynamic>> _transactions = [];
  final List<Map<String, dynamic>> _tickets = [];
  bool _dailyClaimed = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path.split('?').first;
    final method = options.method.toUpperCase();

    if (path == '/users/me' && method == 'GET') return _ok(handler, options, Map<String, dynamic>.from(_user));
    if (path == '/users/me' && method == 'PATCH') {
      final data = _map(options.data);
      if (data['username'] != null) _user['username'] = data['username'];
      if (data['avatarUrl'] != null) _user['avatarUrl'] = data['avatarUrl'];
      return _ok(handler, options, Map<String, dynamic>.from(_user));
    }

    if (path == '/auth/register' || path == '/auth/login' || path == '/auth/guest') {
      final data = _map(options.data);
      if (data['username'] != null) _user['username'] = data['username'];
      if (data['email'] != null) _user['email'] = data['email'];
      return _ok(handler, options, {
        'accessToken': 'mock-access-token',
        'refreshToken': 'mock-refresh-token',
        'user': Map<String, dynamic>.from(_user),
      });
    }
    if (path == '/auth/password/forgot' || path == '/auth/password/reset') return _ok(handler, options, {'success': true});
    if (path == '/auth/session/heartbeat' || path == '/auth/logout') return _ok(handler, options, {'alive': true});
    if (path == '/auth/sessions' && method == 'GET') {
      return _ok(handler, options, [
        {
          'id': '30000000-0000-4000-8000-000000000001',
          'userAgent': 'Mock Android Device',
          'ipAddress': '127.0.0.1',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'lastUsedAt': DateTime.now().toUtc().toIso8601String(),
          'expiresAt': '2030-01-01T00:00:00.000Z',
        }
      ]);
    }
    if (path.startsWith('/auth/sessions/') && method == 'DELETE') return _ok(handler, options, {'success': true});

    if (path == '/games/active/me') return _ok(handler, options, const <dynamic>[]);
    if (path == '/chat/messages') {
      return _ok(handler, options, const [
        {'id': '40000000-0000-4000-8000-000000000001', 'textFa': 'آفرین!', 'emoji': '👏'},
        {'id': '40000000-0000-4000-8000-000000000002', 'textFa': 'چه شانسی!', 'emoji': '🎲'},
      ]);
    }

    if (path == '/shop/items') return _ok(handler, options, _items.map((item) => Map<String, dynamic>.from(item)).toList());
    if (path == '/shop/inventory') return _ok(handler, options, _inventory.map((item) => Map<String, dynamic>.from(item)).toList());
    if (path == '/shop/equip') {
      final itemId = _map(options.data)['itemId'];
      for (final entry in _inventory) {
        entry['equipped'] = entry['itemId'] == itemId;
      }
      return _ok(handler, options, {'success': true});
    }
    if (path == '/shop/purchase') return _purchase(options, handler);

    if (path == '/wallet/daily-reward') {
      if (_dailyClaimed) return _fail(handler, options, 409, 'Daily reward already claimed');
      _dailyClaimed = true;
      _user['coinBalance'] = (_user['coinBalance'] as int) + 100;
      _addTransaction('DAILY_REWARD', 100);
      return _ok(handler, options, {'amount': 100, 'balance': _user['coinBalance']});
    }
    if (path == '/wallet/transactions') return _ok(handler, options, _transactions.map((item) => Map<String, dynamic>.from(item)).toList());

    if (path == '/support/tickets' && method == 'GET') return _ok(handler, options, _tickets.map((item) => Map<String, dynamic>.from(item)).toList());
    if (path == '/support/tickets' && method == 'POST') {
      final data = _map(options.data);
      final ticket = {
        'id': 'ticket-${_tickets.length + 1}',
        'subject': data['subject'],
        'message': data['message'],
        'status': 'OPEN',
        'response': null,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      _tickets.insert(0, ticket);
      return _ok(handler, options, ticket, statusCode: 201);
    }

    if (path == '/payments' && method == 'GET') return _ok(handler, options, const <dynamic>[]);
    if (path == '/payments/verify') return _ok(handler, options, {'status': 'SUCCEEDED'});

    return _fail(handler, options, 404, 'Mock endpoint is not implemented: $method $path');
  }

  void _purchase(RequestOptions options, RequestInterceptorHandler handler) {
    final itemId = _map(options.data)['itemId'];
    final item = _items.where((candidate) => candidate['id'] == itemId).firstOrNull;
    if (item == null) return _fail(handler, options, 404, 'Item not found');
    final price = item['coinPrice'] as int;
    final balance = _user['coinBalance'] as int;
    if (balance < price) return _fail(handler, options, 400, 'Insufficient coin balance');
    _user['coinBalance'] = balance - price;
    if (item['type'] == 'FATTAH') {
      _user['fattahBalance'] = (_user['fattahBalance'] as int) + 1;
    } else {
      final existing = _inventory.where((entry) => entry['itemId'] == itemId).firstOrNull;
      if (existing == null) {
        _inventory.add({'userId': _user['id'], 'itemId': itemId, 'quantity': 1, 'equipped': false, 'item': Map<String, dynamic>.from(item)});
      } else {
        existing['quantity'] = (existing['quantity'] as int) + 1;
      }
    }
    _addTransaction(item['type'] == 'FATTAH' ? 'FATTAH_PURCHASE' : 'SHOP_PURCHASE', -price);
    _ok(handler, options, {'status': 'SUCCEEDED', 'balanceAfter': _user['coinBalance']});
  }

  void _addTransaction(String type, int amount) {
    _transactions.insert(0, {
      'id': 'transaction-${_transactions.length + 1}',
      'type': type,
      'status': 'SUCCEEDED',
      'currency': 'COIN',
      'amount': amount,
      'balanceAfter': _user['coinBalance'],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Map<String, dynamic> _map(dynamic data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  void _ok(RequestInterceptorHandler handler, RequestOptions options, dynamic data, {int statusCode = 200}) {
    handler.resolve(Response<dynamic>(requestOptions: options, data: data, statusCode: statusCode));
  }

  void _fail(RequestInterceptorHandler handler, RequestOptions options, int status, String message) {
    final response = Response<dynamic>(requestOptions: options, statusCode: status, data: {'message': message});
    handler.reject(DioException(requestOptions: options, response: response, type: DioExceptionType.badResponse));
  }
}
