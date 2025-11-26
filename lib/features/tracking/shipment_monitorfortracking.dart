import 'package:supabase_flutter/supabase_flutter.dart';

class ShipmentMonitor {
  final SupabaseClient supabaseClient;
  final String customUserId;
  final Function(Map<String, dynamic>? shipment) onShipmentUpdate;

  RealtimeChannel? _shipmentChannel;
  bool _isRunning = false;

  ShipmentMonitor({
    required this.supabaseClient,
    required this.customUserId,
    required this.onShipmentUpdate,
  });

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    print("ShipmentMonitor: Started for user $customUserId");

    _fetchInitialShipment();
    _subscribeToChanges();
  }

  void stop() {
    print("ShipmentMonitor: Stopped.");

    if (_shipmentChannel != null) {
      supabaseClient.removeChannel(_shipmentChannel!);
    }

    _isRunning = false;
  }

  Future<void> _fetchInitialShipment() async {
    try {
      final response = await supabaseClient
          .from('shipment')
          .select()
          .eq('assigned_driver', customUserId)
          .inFilter('booking_status', [
        'Accepted',
        'En Route to Pickup',
        'Arrived at Pickup',
        'In Transit',
      ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      onShipmentUpdate(response);
    } catch (e) {
      print("ShipmentMonitor Error: Failed to fetch initial shipment: $e");
    }
  }

  void _subscribeToChanges() {
    _shipmentChannel = supabaseClient.channel(
      'public:shipment:assigned_driver=eq.$customUserId',
    );

    _shipmentChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'shipment',
      callback: (payload) {
        print("ShipmentMonitor: Change detected → refetching...");
        _fetchInitialShipment();
      },
    )
        .subscribe();
  }
}