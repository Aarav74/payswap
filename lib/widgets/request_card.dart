// widgets/request_card.dart (updated)
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/request_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class RequestCard extends StatelessWidget {
  final Request request;

  const RequestCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    Provider.of<LocationService>(context);
    final distance = request.distance;
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.userName} needs ${request.type == 'Need Cash' ? 'cash' : 'online payment'}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('Amount: \$${request.amount.toStringAsFixed(2)}'),
            if (distance != null)
              Text('Distance: ${distance.toStringAsFixed(2)} km away'),
            SizedBox(height: 4),
            SizedBox(height: 4),
            Text('Status: ${request.status}'),
            SizedBox(height: 4),
            Text('Created: ${_formatDate(request.createdAt)}'),
            SizedBox(height: 12),
            if (request.status == 'pending')
              ElevatedButton(
                onPressed: () => _acceptRequest(apiService, context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('Accept Request'),
              )
            else if (request.status == 'accepted')
              Text(
                'Accepted',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              )
            else if (request.status == 'completed')
              Text(
                'Completed',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _acceptRequest(ApiService apiService, BuildContext context) async {
    try {
      await apiService.acceptRequest(request.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request accepted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: $e')),
      );
    }
  }
}