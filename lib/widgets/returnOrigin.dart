// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, avoid_print, prefer_is_not_empty, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'getStreetNumber.dart';
import '../config/config.dart';

class ReturnOrigin extends StatefulWidget {
  String originText;
  ReturnOrigin(this.originText);
  @override
  State<ReturnOrigin> createState() => _ReturnOriginState();
}

class _ReturnOriginState extends State<ReturnOrigin> {
  Config config = Config();
  TextEditingController textFieldController = TextEditingController();
  List<String> suggestions = [];

  Future<List<String>> fetchLocation(String query) async {
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

  void _sendDataBack(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GetStreetNumber(textFieldController.text),
      ),
    );
    if (result != null) {
      textFieldController.text = result;
    }
    String textToSendBack = textFieldController.text;
    if (textToSendBack.isEmpty) return;
    Navigator.pop(context, textToSendBack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(9, 89, 95, 1),
        title: Text(
          'Starting Point',
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        color: Theme.of(context).primaryColor,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 15, right: 10, left: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(left: 10, right: 5),
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
                            labelText: widget.originText,
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                          ),
                          style: TextStyle(
                            fontSize: 20,
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
    );
  }
}
