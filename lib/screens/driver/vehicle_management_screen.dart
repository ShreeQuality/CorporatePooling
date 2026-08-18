import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/vehicle_model.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({Key? key}) : super(key: key);

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final List<VehicleModel> _vehicles = [
    VehicleModel(
      id: 'v1',
      userId: 'u1',
      vehicleType: 'car',
      vehicleNumber: 'KA01AB1234',
      vehicleMake: 'Honda',
      vehicleModel: 'City ZX',
      vehicleColor: 'Pearl White',
      isVerified: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Registered Vehicles 🚗')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _vehicles.length,
        itemBuilder: (context, idx) {
          final v = _vehicles[idx];
          return Card(
            color: AppTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.accentGreen.withOpacity(0.2),
                child: Icon(v.isTwoWheeler ? Icons.two_wheeler : Icons.directions_car, color: AppTheme.accentGreen),
              ),
              title: Text('${v.vehicleMake} ${v.vehicleModel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(v.vehicleNumber, style: const TextStyle(color: Colors.white70)),
              trailing: v.isVerified
                  ? const Chip(label: Text('Verified ✅', style: TextStyle(fontSize: 11, color: Colors.greenAccent)), backgroundColor: Colors.black26)
                  : const Chip(label: Text('Pending RC', style: TextStyle(fontSize: 11, color: Colors.orangeAccent)), backgroundColor: Colors.black26),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentGreen,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Register Vehicle', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: _showAddVehicleModal,
      ),
    );
  }

  void _showAddVehicleModal() {
    final plateController = TextEditingController();
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    String selectedType = 'car';
    bool spareHelmet = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Register New Vehicle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: AppTheme.cardDark,
                      items: const [
                        DropdownMenuItem(value: 'car', child: Text('Car / Sedan (4-Wheeler)', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'suv', child: Text('SUV / MUV', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'bike', child: Text('Motorcycle (2-Wheeler)', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'scooter', child: Text('Scooter / EV Scooter', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'ev', child: Text('Electric Car (EV)', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) => setModalState(() => selectedType = val!),
                      decoration: const InputDecoration(labelText: 'Vehicle Type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Vehicle Plate Number (e.g. KA01AB1234)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: makeController, decoration: const InputDecoration(labelText: 'Make (e.g. Tata)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model (e.g. Nexon EV)'))),
                      ],
                    ),
                    if (selectedType == 'bike' || selectedType == 'scooter') ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: spareHelmet,
                        onChanged: (val) => setModalState(() => spareHelmet = val!),
                        title: const Text('I carry a spare helmet for passenger', style: TextStyle(color: Colors.white, fontSize: 13)),
                        activeColor: AppTheme.accentGreen,
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: const Text('Submit for RC Verification'),
                        onPressed: () {
                          if (plateController.text.isNotEmpty) {
                            setState(() {
                              _vehicles.add(VehicleModel(
                                id: 'v_${DateTime.now().millisecondsSinceEpoch}',
                                userId: 'u1',
                                vehicleType: selectedType,
                                vehicleNumber: plateController.text.trim(),
                                vehicleMake: makeController.text.trim(),
                                vehicleModel: modelController.text.trim(),
                                hasSpareHelmet: spareHelmet,
                              ));
                            });
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
