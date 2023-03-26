// ignore_for_file: prefer_const_constructors, sort_child_properties_last, import_of_legacy_library_into_null_safe, prefer_is_not_empty, unnecessary_null_comparison, deprecated_member_use, depend_on_referenced_packages, avoid_function_literals_in_foreach_calls, prefer_final_fields
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'widgets/returnOrigin.dart';
import 'widgets/returnDestination.dart';
import 'widgets/directionsRepo.dart';
import 'widgets/directions.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:weather_icons/weather_icons.dart';
import 'config/config.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter App',
      home: MyHomePage(),
      theme: ThemeData(
        fontFamily: 'Rubik',
        //  Color.fromRGBO(23, 26, 32, 1),
        // Color.fromRGBO(13, 108, 114, 1)
        primaryColor: Color.fromRGBO(23, 26, 32, 1),
        accentColor: Color.fromRGBO(250, 250, 250, 1),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Config config = Config();
  // Initial map coords and map controller to control camera movements.
  static const _initialCameraPosition =
      CameraPosition(target: LatLng(52.5163, 13.3777), zoom: 12);
  late GoogleMapController _mapController;

  // Input field texts for origin/dest points.
  String originText = 'Starting Point...';
  String destinationText = 'Destination...';

  // Set origin/dest coords, respective markers, lat/lng coords between poits and polyline corresponding to coords.
  late LatLng _originCoordinates;
  late LatLng _destCoordinates;
  int _markerCounter = 0;
  Set<Marker> _markers = {};
  late Directions _info;
  Set<Polyline> _polyline = {};
  String _totalDuration = '';
  String _totalDistance = '';

  // Variables for calendar and weather filter
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  bool _isDateChosen = false;
  bool _showAdditionalButtons = false;
  List<String> _selectedOptions = [];
  var _dateRangeArray = [];
  var _availableDatesForTrip = [];

  // Weather API
  var _forecastList = [];
  bool _isCollapsed = false;

  // Format input text.
  String getFormattedText(String inputText) {
    if (inputText != null) {
      if (inputText.length > 15) {
        return '${inputText.substring(0, 15)}...';
      }
    }
    return inputText;
  }

  // -------------------Section For Input Pages-------------------
  // Wait return value of input page to take origin point and update it's coords.
  void _awaitStartingPointReturnValue(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnOrigin(originText),
      ),
    );
    if (result != null) {
      List<Location> originLoc = await locationFromAddress(result);
      setState(() {
        originText = result;
        _originCoordinates =
            LatLng(originLoc[0].latitude, originLoc[0].longitude);
      });
    }
    // Toggle keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    // Animate camera to the starting point.
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _originCoordinates, zoom: 14),
      ),
    );
    setState(() {
      _markers = {};
    });
    _addOriginMarker();
    _resetPolyline();
  }

  // Wait return value of input page to take dest point and update it's coords.
  void _awaitDestinationPointReturnValue(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnDestination(destinationText),
      ),
    );
    if (result != null) {
      List<Location> destLoc = await locationFromAddress(result);
      setState(
        () {
          destinationText = result;
          _destCoordinates = LatLng(destLoc[0].latitude, destLoc[0].longitude);
        },
      );
    }
    // Toggle keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    // Animate camera to the destination point.
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _destCoordinates, zoom: 14),
      ),
    );
    if (_markers.length > 1) {
      _markers.remove(_markers.last);
    }
    setState(() {
      _markers;
    });
    _addDestinationMarker();
    _resetPolyline();
  }

  // -----------Section For Map Operations, Coords, Polyline..----------------
  // Get shortest path.
  void _getShortestPath() async {
    _getWeather();
    _resetPolyline();
    _drawPolyline();
  }

  // Add markers for origin/dest coords.
  void _addOriginMarker() {
    _markers.add(
      Marker(
        markerId: MarkerId('origin'),
        infoWindow: InfoWindow(title: 'Origin'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        position: _originCoordinates,
      ),
    );
    setState(() {
      _markers;
      _markerCounter = 1;
    });
  }

  void _addDestinationMarker() {
    _markers.add(
      Marker(
        markerId: MarkerId('destination'),
        infoWindow: InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        position: _destCoordinates,
      ),
    );
    setState(() {
      _markers;
      _markerCounter = 0;
    });
  }

  // Get coords between origin/dest points corresponding to shortest path and update _info.
  // This part is going to be updated to take directions from backend instead of Direction API.
  Future<Directions> _getDirections() async {
    final directions = await DirectionsRepo().getDirections(
        origin: _originCoordinates, destination: _destCoordinates);

    setState(() {
      _info = directions;
    });

    return _info;
  }

  // Draw Polyline between given list of coordinates and update _polyline
  void _drawPolyline() {
    _getDirections().then((value) {
      _polyline.add(Polyline(
        polylineId: PolylineId("polylineId"),
        color: Theme.of(context).primaryColor,
        width: 4,
        points: value.polylinePoints
            .map((e) => LatLng(e.latitude, e.longitude))
            .toList(),
      ));
      _totalDuration = value.totalDuration;
      _totalDistance = value.totalDistance;
      setState(() {
        _polyline;
        _totalDuration;
        _totalDistance;
      });
      // Animate camera to the shortest path.
      _mapController.animateCamera(
        CameraUpdate.newLatLngBounds(_info.bounds, 110.0),
      );
    });
  }

  // Helper function to reset polyline before calculating new polyline for another route.
  void _resetPolyline() {
    _polyline = {};
    setState(() {
      _polyline;
    });
  }

  // Helper function to reset marker.
  void _resetOriginMarker() {
    _markers = {};
    setState(() {
      _markers;
    });
  }

  // Get user location info with geolocation.
  _getCurrentLocation() async {
    await Geolocator.requestPermission().then(
      (value) => {
        Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.best,
                forceAndroidLocationManager: true)
            .then(
          (Position position) async {
            final url = Uri.parse(
                'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${config.GOOGLE_API}');
            final response = await http.get(url);
            setState(() {
              originText =
                  json.decode(response.body)['results'][0]['formatted_address'];
              _originCoordinates =
                  LatLng(position.latitude, position.longitude);
            });
            _mapController.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _destCoordinates, zoom: 14),
              ),
            );
            _addDestinationMarker();
            _resetPolyline();
          },
        ).catchError(
          (e) {
            print(e);
          },
        ),
      },
    );
  }

  // Add origin marker on touch.
  void _appearOriginMarkerOnTouch(LatLng pos) async {
    _resetPolyline();
    _resetOriginMarker();
    _markers.add(
      Marker(
        markerId: MarkerId('origin'),
        infoWindow: InfoWindow(title: 'Origin'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        position: pos,
      ),
    );
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=${config.GOOGLE_API}');
    final response = await http.get(url);
    originText = json.decode(response.body)['results'][0]['formatted_address'];
    setState(() {
      _markers;
      originText;
      _originCoordinates = LatLng(pos.latitude, pos.longitude);
      _markerCounter = 1;
    });
  }

  // Add destination marker on touch.
  void _appearDestMarkerOnTouch(LatLng pos) async {
    _resetPolyline();

    _markers.add(
      Marker(
        markerId: MarkerId('dest'),
        infoWindow: InfoWindow(title: 'Dest'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        position: pos,
      ),
    );
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=${config.GOOGLE_API}');
    final response = await http.get(url);
    destinationText =
        json.decode(response.body)['results'][0]['formatted_address'];
    setState(() {
      _markers;
      destinationText;
      _destCoordinates = LatLng(pos.latitude, pos.longitude);
      _markerCounter = 0;
    });
  }

// ----------Section For Filter Functions, Calendar, Weather------------
// Pick date
  _rangeDatePicker(BuildContext ctx) async {
    DateTimeRange? newDateTimeRange = await showDateRangePicker(
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color.fromRGBO(9, 89, 95, 1),
              onPrimary: Theme.of(context).accentColor,
              onSurface: Theme.of(context).accentColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                primary: Theme.of(context).accentColor, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    // Update chosen date of global date variable.
    if (newDateTimeRange == null) return;
    setState(() {
      _dateRange = newDateTimeRange;
      _isDateChosen = true;
    });
    _updateDateRange();
  }

  // Update Data Range Array
  void _updateDateRange() {
    DateFormat formatter = DateFormat('y-MM-dd');
    String formattedStart = formatter.format(_dateRange.start);
    String formattedEnd = formatter.format(_dateRange.end);
    _dateRangeArray.add(formattedStart);
    _dateRangeArray.add(formattedEnd);
  }

  // Format and display date.
  String convertDateFormat(date) {
    DateFormat formatter = DateFormat('MM/dd');
    String formatted = formatter.format(date);
    return formatted;
  }

  String displayDate() {
    if (_isDateChosen) {
      return "${convertDateFormat(_dateRange.start)} - ${convertDateFormat(_dateRange.end)}";
    }
    return '';
  }

  // Expand buttons
  void _toggleAdditionalButtons() {
    setState(() {
      _showAdditionalButtons = !_showAdditionalButtons;
    });
  }

  // Show weather options as modal bottom sheet
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(WeatherIcons.rain),
                title: Text('Rain'),
                onTap: () {
                  setState(() {
                    if (!_selectedOptions.contains('Rain')) {
                      _selectedOptions.add('Rain');
                    }
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(WeatherIcons.wind_beaufort_1),
                title: Text('Wind'),
                onTap: () {
                  setState(() {
                    if (!_selectedOptions.contains('Wind')) {
                      _selectedOptions.add('Wind');
                    }
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(WeatherIcons.snow),
                title: Text('Snow'),
                onTap: () {
                  setState(() {
                    if (!_selectedOptions.contains('Snow')) {
                      _selectedOptions.add('Snow');
                    }
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(WeatherIcons.fog),
                title: Text('Frost'),
                onTap: () {
                  setState(() {
                    if (!_selectedOptions.contains('Frost')) {
                      _selectedOptions.add('Frost');
                    }
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Display selected weather conditions with icons
  List<Widget> returnWidget() {
    List<Widget> widgetList = [];
    for (var item in _selectedOptions) {
      widgetList.add(Text(
        item,
        style: TextStyle(
            letterSpacing: 0.6,
            fontSize: 19,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).accentColor),
      ));
      widgetList.add(SizedBox(
        child: Text('  '),
      ));
      widgetList.add(
        Container(margin: EdgeInsets.only(bottom: 10), child: getIcon(item)),
      );
      widgetList.add(
        Text(
          ' ,  ',
          style: TextStyle(color: Theme.of(context).accentColor, fontSize: 26),
        ),
      );
    }
    return widgetList.sublist(0, widgetList.length - 1);
  }

  // Helper function to get corresponding icon
  Icon getIcon(String iconName) {
    switch (iconName) {
      case 'Rain':
        return Icon(
          WeatherIcons.rain,
          color: Theme.of(context).accentColor,
          size: 22,
        );
      case 'Wind':
        return Icon(
          WeatherIcons.wind_beaufort_1,
          color: Theme.of(context).accentColor,
          size: 22,
        );
      case 'Snow':
        return Icon(
          WeatherIcons.snow,
          color: Theme.of(context).accentColor,
          size: 22,
        );
      case 'Frost':
        return Icon(
          WeatherIcons.fog,
          color: Theme.of(context).accentColor,
          size: 22,
        );
      default:
        return Icon(Icons.abc);
    }
  }

  // ----------Section For Getting Weather Data------------
  // Create weather query to the external weather API
  void _getWeather() async {
    _forecastList = [];
    setState(() {
      _forecastList;
    });
    final response = await http.get(
      Uri.parse(
        'http://api.weatherapi.com/v1/forecast.json?key=${config.WEATHER_API}&q=${_destCoordinates.latitude},${_destCoordinates.longitude}&days=14',
      ),
    );

    // Get weather information for destination point and update list for available dates of trip.
    var data = jsonDecode(response.body);
    var forecast = data['forecast']['forecastday'];
    forecast.forEach(
      (item) => {
        _forecastList.add(
          {
            'date': item['date'],
            'chanceOfRain': item['day']['daily_chance_of_rain'],
            'chanceOfSnow': item['day']['daily_chance_of_snow'],
            'condition': item['day']['condition']['text'],
          },
        )
      },
    );
    _getAvailableDates();
  }

  void _getAvailableDates() {
    _availableDatesForTrip = [];
    setState(() {
      _availableDatesForTrip;
    });
    var format = DateFormat('y-dd-mm');
    var sinceEpochStart =
        format.parse(_dateRangeArray[0], true).millisecondsSinceEpoch;
    var sinceEpochEnd =
        format.parse(_dateRangeArray[1], true).millisecondsSinceEpoch;
    _forecastList.forEach((element) {
      final dt = format.parse(element['date'], true).millisecondsSinceEpoch;
      if (sinceEpochStart < dt && dt < sinceEpochEnd) {
        if (_selectedOptions.contains('Rain') &&
            _selectedOptions.contains('Snow')) {
          if ((element['chanceOfRain'].toInt() < 87) &&
              (element['chanceOfSnow'].toInt() < 85)) {
            _availableDatesForTrip.add(element['date']);
          }
        } else if (_selectedOptions.contains('Rain')) {
          if (element['chanceOfRain'].toInt() < 87) {
            _availableDatesForTrip.add(element['date']);
          }
        } else if (_selectedOptions.contains('Snow')) {
          if (element['chanceOfSnow'].toInt() < 85) {
            _availableDatesForTrip.add(element['date']);
          }
        } else {
          _availableDatesForTrip.add(element['date']);
        }
      }
      setState(() {
        _availableDatesForTrip;
      });
    });
  }

  void _collapse() {
    if (_isCollapsed) {
      _isCollapsed = false;
    } else {
      _isCollapsed = true;
    }
    setState(() {
      _isCollapsed;
    });
  }

  // Main App
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
              initialCameraPosition: _initialCameraPosition,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polyline,
              onLongPress: _markerCounter == 0
                  ? _appearOriginMarkerOnTouch
                  : _appearDestMarkerOnTouch),
          SafeArea(
            child: Column(
              children: [
                // Starting Input
                Container(
                  margin:
                      EdgeInsets.only(top: 10, right: 20, bottom: 10, left: 20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 0.7,
                      color: Color.fromRGBO(0, 0, 0, 0.4),
                    ),
                    color: Theme.of(context).accentColor,
                    borderRadius: BorderRadius.all(
                      Radius.circular(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Container(
                          padding: EdgeInsets.only(right: 15, left: 10),
                          child: Icon(
                            Icons.person_pin_circle_outlined,
                            size: 32,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            decoration: InputDecoration(
                              labelStyle: TextStyle(
                                letterSpacing: 1,
                                color: Color.fromRGBO(20, 20, 20, 1),
                              ),
                              border: InputBorder.none,
                              prefixText: getFormattedText(originText),
                              labelText: getFormattedText(originText),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                            ),
                            style: TextStyle(
                              fontSize: 20,
                            ),
                            onTap: () {
                              _awaitStartingPointReturnValue(context);
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: Container(
                          padding: EdgeInsets.only(right: 6, left: 10),
                          child: IconButton(
                            iconSize: 24,
                            icon: Icon(
                              Icons.my_location_outlined,
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed: _getCurrentLocation,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Destination Input
                Container(
                  margin: EdgeInsets.only(right: 20, bottom: 15, left: 20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 0.7,
                      color: Color.fromRGBO(0, 0, 0, 0.4),
                    ),
                    color: Theme.of(context).accentColor,
                    borderRadius: BorderRadius.all(
                      Radius.circular(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Container(
                          padding: EdgeInsets.only(right: 15, left: 10),
                          child: Icon(
                            Icons.pin_drop_outlined,
                            size: 32,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            decoration: InputDecoration(
                              labelStyle: TextStyle(
                                letterSpacing: 1,
                                color: Color.fromRGBO(20, 20, 20, 1),
                              ),
                              border: InputBorder.none,
                              prefixText: getFormattedText(destinationText),
                              labelText: getFormattedText(destinationText),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                            ),
                            style: TextStyle(
                              fontSize: 20,
                            ),
                            onTap: () {
                              _awaitDestinationPointReturnValue(context);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        child: Container(
                          margin: EdgeInsets.only(left: 25),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 23,
                                    backgroundColor:
                                        Color.fromRGBO(9, 89, 95, 1),
                                    child: IconButton(
                                      onPressed: _toggleAdditionalButtons,
                                      icon: Icon(Icons.menu),
                                      color: Theme.of(context).accentColor,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  if (_showAdditionalButtons)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                Color.fromRGBO(9, 89, 95, 1),
                                            radius: 20,
                                            child: IconButton(
                                              onPressed: () {
                                                _rangeDatePicker(context);
                                                // Do something when the first additional button is pressed
                                              },
                                              icon: Icon(Icons.calendar_month),
                                              color:
                                                  Theme.of(context).accentColor,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          CircleAvatar(
                                            backgroundColor:
                                                Color.fromRGBO(9, 89, 95, 1),
                                            radius: 20,
                                            child: IconButton(
                                              onPressed: () {
                                                _showOptions(context);
                                                // Do something when the second additional button is pressed
                                              },
                                              icon: Icon(Icons.sunny),
                                              color:
                                                  Theme.of(context).accentColor,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      child: RawMaterialButton(
                        onPressed: _getShortestPath,
                        elevation: 5,
                        fillColor: Color.fromRGBO(9, 89, 95, 1),
                        child: Icon(
                          Icons.navigation_rounded,
                          color: Theme.of(context).accentColor,
                          size: 24,
                        ),
                        padding: EdgeInsets.all(12),
                        shape: CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.1,
            minChildSize: 0.1,
            maxChildSize: 0.2,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                  ),
                  color: Theme.of(context).primaryColor,
                ),
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 1,
                  padding: EdgeInsets.all(20),
                  itemBuilder: (BuildContext context, int index) {
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: 15, top: 5),
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(53, 56, 63, 1),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(25))),
                            padding:
                                EdgeInsets.only(bottom: 15, top: 15, left: 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.only(right: 5, top: 2),
                                  child: Icon(
                                    Icons.calendar_month,
                                    color: Theme.of(context).accentColor,
                                    size: 20,
                                  ),
                                ),
                                Text(
                                  'Picked Date:  ',
                                  style: TextStyle(
                                      letterSpacing: 0.6,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).accentColor),
                                ),
                                Text(
                                  displayDate(),
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context).accentColor),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(53, 56, 63, 1),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(25))),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.only(
                                      bottom: 5, top: 15, left: 17),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(
                                          WeatherIcons.cloudy,
                                          color: Theme.of(context).accentColor,
                                          size: 18,
                                        ),
                                      ),
                                      Text(
                                        'Undesired Weather:  ',
                                        style: TextStyle(
                                            letterSpacing: 0.6,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Theme.of(context).accentColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                    ),
                                    if (!_selectedOptions.isEmpty)
                                      ...returnWidget(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.only(top: 7, bottom: 7),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: _collapse,
                                  child: Container(
                                    padding: EdgeInsets.only(
                                        top: 10,
                                        bottom: 10,
                                        left: 135,
                                        right: 135),
                                    child: Text(
                                      'Info',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStatePropertyAll(
                                      Color.fromRGBO(13, 108, 114, 1),
                                    ),
                                    shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_availableDatesForTrip != null && _isCollapsed)
                            Container(
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(53, 56, 63, 1),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(25))),
                              padding: EdgeInsets.only(
                                  top: 15, left: 20, bottom: 15),
                              margin: EdgeInsets.only(top: 10, bottom: 10),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding:
                                            EdgeInsets.only(right: 5, top: 2),
                                        child: Icon(
                                          Icons.access_time_filled_outlined,
                                          color: Theme.of(context).accentColor,
                                          size: 20,
                                        ),
                                      ),
                                      Text(
                                        'Duration:  ',
                                        style: TextStyle(
                                            letterSpacing: 0.6,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Theme.of(context).accentColor),
                                      ),
                                      Text(
                                        _totalDuration,
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w400,
                                            color:
                                                Theme.of(context).accentColor),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 15,
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding:
                                            EdgeInsets.only(right: 5, top: 2),
                                        child: Icon(
                                          Icons.directions_car_rounded,
                                          color: Theme.of(context).accentColor,
                                          size: 20,
                                        ),
                                      ),
                                      Text(
                                        'Distance:  ',
                                        style: TextStyle(
                                            letterSpacing: 0.6,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Theme.of(context).accentColor),
                                      ),
                                      Text(
                                        _totalDistance,
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w400,
                                            color:
                                                Theme.of(context).accentColor),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          if (_availableDatesForTrip != null && _isCollapsed)
                            Container(
                              margin: EdgeInsets.only(top: 10),
                              padding: EdgeInsets.only(left: 5, top: 10),
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(53, 56, 63, 1),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(25))),
                              child: Column(
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: EdgeInsets.only(
                                          right: 3,
                                          top: 4,
                                          bottom: 7,
                                          left: 15),
                                      child: Icon(
                                        Icons.event_available,
                                        color: Theme.of(context).accentColor,
                                        size: 24,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.only(
                                          top: 5, left: 5, bottom: 10),
                                      child: Text(
                                        'Available Dates:',
                                        style: TextStyle(
                                            letterSpacing: 0.6,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Theme.of(context).accentColor),
                                      ),
                                    ),
                                  ]),
                                  for (var i = 0;
                                      i < _availableDatesForTrip.length;
                                      i++)
                                    Container(
                                      padding: const EdgeInsets.only(
                                          top: 5, bottom: 15, left: 5),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.only(
                                                right: 6, left: 12),
                                            child: Icon(
                                              Icons.check_rounded,
                                              color:
                                                  Theme.of(context).accentColor,
                                              size: 20,
                                            ),
                                          ),
                                          Text(
                                            _availableDatesForTrip[i],
                                            style: TextStyle(
                                                letterSpacing: 0.6,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w400,
                                                color: Theme.of(context)
                                                    .accentColor),
                                          ),
                                        ],
                                      ),
                                    )
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          )
        ],
      ),
    );
  }
}
