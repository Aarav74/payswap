import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/request_model.dart';
import '../services/api_service.dart';
import '../widgets/request_card.dart';

class RequestScreen extends StatefulWidget {
  @override
  _RequestScreenState createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _amountController = TextEditingController();
  String _selectedType = 'Need Cash';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Create Request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField(
                    value: _selectedType,
                    items: ['Need Cash', 'Need Online Payment']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value.toString();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Request Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _createRequest(apiService),
                    child: _isLoading 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Create Request'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Request>>(
              future: apiService.getNearbyRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No requests nearby'));
                }
                
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    return RequestCard(request: snapshot.data![index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _createRequest(ApiService apiService) async {
    if (_amountController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final amount = double.parse(_amountController.text);
      await apiService.createRequest(
        amount: amount,
        type: _selectedType,
      );
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request created successfully')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating request: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}