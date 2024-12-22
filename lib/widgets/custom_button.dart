import 'package:flutter/material.dart'; // Importing the Flutter material package for UI components

class CustomButton extends StatelessWidget { // Defining a stateless widget called CustomButton
  final String label; // A final variable to hold the button label text
  final VoidCallback? onPressed; // A final variable to hold the callback function when the button is pressed
  final bool isLoading; // A final variable to indicate if the button is in a loading state

  const CustomButton({ // Constructor for the CustomButton class
    super.key, // Passing the key to the superclass constructor
    required this.label, // Initializing the label variable
    required this.onPressed, // Initializing the onPressed variable
    this.isLoading = false, // Initializing the isLoading variable with a default value of false
  });

  @override
  Widget build(BuildContext context) { // Overriding the build method to define the UI
    return ElevatedButton( // Returning an ElevatedButton widget
      onPressed: onPressed, // Setting the onPressed callback
      style: ElevatedButton.styleFrom( // Customizing the button style
        padding: const EdgeInsets.symmetric(vertical: 16), // Adding vertical padding
        shape: RoundedRectangleBorder( // Defining the button shape
          borderRadius: BorderRadius.circular(8), // Setting the border radius
        ),
      ),
      child: isLoading // Checking if the button is in a loading state
          ? const SizedBox( // If loading, show a CircularProgressIndicator
              height: 20, // Setting the height of the progress indicator
              width: 20, // Setting the width of the progress indicator
              child: CircularProgressIndicator( // Defining the progress indicator
                strokeWidth: 2, // Setting the stroke width
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Setting the color to white
              ),
            )
          : Text( // If not loading, show the button label
              label, // Setting the button label text
              style: const TextStyle(fontSize: 16), // Defining the text style
            ),
    );
  }
}
