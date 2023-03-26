// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, sort_child_properties_last, must_be_immutable, use_key_in_widget_constructors, avoid_unnecessary_containers, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import '../config/config.dart';

class GetStreetNumber extends StatefulWidget {
  String currentAddress;
  GetStreetNumber(this.currentAddress);

  @override
  State<GetStreetNumber> createState() => _GetStreetNumberState();
}

class _GetStreetNumberState extends State<GetStreetNumber> {
  Config config = Config();
  TextEditingController textFieldController = TextEditingController();
  List<String> suggestions = [];

  Future<List<String>> fetchLocation(String query) async {
    query = widget.currentAddress + query;
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&radius=500&key=${config.GOOGLE_API}',
      ),
    );
    var jsonData = jsonDecode(response.body);
    suggestions = [];
    for (int i = 0; i < jsonData['predictions'][i].length; i++) {
      suggestions.add(jsonData['predictions'][i]['description'].toString());
    }
    return suggestions;
  }

  void _sendDataBack(BuildContext context) {
    Navigator.pop(context, textFieldController.text);
  }

  void _skip(BuildContext context) {
    Navigator.pop(context, widget.currentAddress);
  }

  void _back(BuildContext context) {
    Navigator.pop(context, textFieldController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(9, 89, 95, 1),
        title: Text(
          'House Number',
          style: TextStyle(
            color: Theme.of(context).accentColor,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          iconSize: 26,
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: Theme.of(context).accentColor,
          ),
          onPressed: () => _back(context),
        ),
      ),
      body: Container(
        color: Theme.of(context).primaryColor,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 15, right: 20, left: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(left: 10, right: 0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          width: 1.5,
                          color: Color.fromRGBO(9, 89, 95, 1),
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(30),
                        ),
                      ),
                      height: 45,
                      child: TypeAheadField(
                        animationStart: 1,
                        animationDuration: Duration.zero,
                        textFieldConfiguration: TextFieldConfiguration(
                          onSubmitted: (_) {
                            _sendDataBack(context);
                          },
                          controller: textFieldController,
                          autofocus: false,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelStyle: TextStyle(
                              color: Theme.of(context).accentColor,
                            ),
                            labelText: 'House number..',
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                          ),
                          style: TextStyle(
                            fontSize: 21,
                            color: Theme.of(context).accentColor,
                          ),
                        ),
                        suggestionsBoxDecoration: SuggestionsBoxDecoration(
                          color: Theme.of(context).primaryColor,
                        ),
                        suggestionsCallback: (pattern) {
                          fetchLocation(pattern);
                          return suggestions;
                        },
                        itemBuilder: (context, textField) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(53, 56, 63, 1),
                              borderRadius: BorderRadius.all(
                                Radius.circular(25),
                              ),
                            ),
                            margin: EdgeInsets.only(top: 5, bottom: 5),
                            padding:
                                EdgeInsets.only(top: 5, bottom: 5, left: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  child: Icon(Icons.location_city_rounded,
                                      color: Theme.of(context).accentColor),
                                ),
                                Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      top: 10,
                                      bottom: 10,
                                      left: 10,
                                    ),
                                    width: double.infinity,
                                    child: Text(
                                      textField.toString(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Theme.of(context).accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onSuggestionSelected: (suggestion) {
                          textFieldController.text = suggestion.toString();
                          _sendDataBack(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ElevatedButton(
        onPressed: () => _skip(context),
        child: Container(
          child: Text(
            'Skip',
            style: TextStyle(fontSize: 20),
          ),
          padding: EdgeInsets.all(10),
        ),
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(
            Color.fromRGBO(13, 108, 114, 1),
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
