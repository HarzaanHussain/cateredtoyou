import 'package:cateredtoyou/services/customer_service.dart';
import 'package:cateredtoyou/utils/validators.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose(){
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleAddCustomer() async{
    if(!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final customerService = Provider.of<CustomerService>(context, listen: false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context){
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      );

      final success = await customerService.createCustomerStandalone(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim()
      );

      if(!mounted) return;

      Navigator.of(context).pop();

      if(success){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer added successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        context.go('/customers');
      }
    }catch (e) {
      if(!mounted) return;

      if(Navigator.canPop(context)){
        Navigator.of(context).pop();
      }

      final errorMessage = e.toString().replaceAll(RegExp(r'^Exception: '), '');

      setState(() {
        _error = errorMessage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            textColor: Colors.white,
          ),
        ),
      );
    } finally{
      if(mounted){
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomToolbar(),
      appBar: AppBar(
        title: const Text('Add Customer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _firstNameController,
                label: 'First Name',
                prefixIcon: Icons.person,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16,),
              CustomTextField(
                controller: _lastNameController,
                label: 'Last Name',
                prefixIcon: Icons.person,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16,),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.person,
                validator: Validators.validateEmail,
              ),
              const SizedBox(height: 16,),
              CustomTextField(
                controller: _phoneNumberController,
                label: 'Phone Number',
                prefixIcon: Icons.person,
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: 16,),
              if(_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                label: 'Add Customer',
                onPressed: _isLoading ? null : _handleAddCustomer,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
