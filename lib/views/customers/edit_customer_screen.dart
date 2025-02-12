import 'package:cateredtoyou/models/customer_model.dart';
import 'package:cateredtoyou/services/customer_service.dart';
import 'package:cateredtoyou/utils/validators.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';
import 'package:cateredtoyou/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class EditCustomerScreen extends StatefulWidget {
  final CustomerModel customer;


  const EditCustomerScreen({
    super.key,
    required this.customer,
  });

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}


class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneNumberController;

  bool _isLoading = false;
  String? _error;
  late final CustomerService _customerService;

  @override
  void initState(){
    super.initState();
    _customerService = Provider.of<CustomerService>(context, listen: false);
    _firstNameController = TextEditingController(
      text: widget.customer.firstName
    );
    _lastNameController = TextEditingController(
      text: widget.customer.lastName
    );
    _emailController = TextEditingController(
        text: widget.customer.email
    );
    _phoneNumberController = TextEditingController(
        text: widget.customer.phoneNumber
    );
  }

  @override
  void dispose(){
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async{
    if(!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try{
      await _customerService.deleteCustomer(widget.customer.id);
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer Deleted Successfully')));
      context.go('/customers');
    }catch (e){
      if(!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }finally{
      if(mounted){
        setState(() {
          _isLoading = false;
        });
      }
    }

  }

  Future<void> _handleUpdate() async{
    if(!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try{
      final updateCustomer = widget.customer.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
      );

      await _customerService.updateCustomer(updateCustomer);

      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer added successfully')));
      context.go('/customers');
    }catch (e){
      if(!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }finally {
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
      appBar: AppBar(
        title: Text('Edit ${widget.customer.fullName}'),
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
                prefixIcon: Icons.email,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 16,),
              CustomTextField(
                controller: _phoneNumberController,
                label: 'Phone Number',
                prefixIcon: Icons.phone,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 24,),
              if(_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                label: 'Update Customer Information',
                onPressed: _isLoading ? null : _handleUpdate,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16,),
              OutlinedButton(
                onPressed: _isLoading ? null : _handleDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(
                    color: Colors.red
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Delete Customer', style: TextStyle(color: Colors.red),),
              )
            ],
          ),
        ),
      ),
    );
  }
}
