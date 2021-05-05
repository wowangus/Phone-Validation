import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:phone_validation/themeValues.dart';

const DEFAULT_AREA = 'HK';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
    // return Listener(
    //   onPointerDown: (e) {
        final FocusScopeNode _currentFirstResponder = FocusScope.of(context);
        if (!_currentFirstResponder.hasPrimaryFocus && _currentFirstResponder.focusedChild != null) {
          // _currentFirstResponder.focusedChild.unfocus();
          
          primaryFocus?.unfocus();
          
          // WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
        }
        
        // primaryFocus?.unfocus();

        // WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
      },
      child: MaterialApp(
        title: 'Phone Validation',
        theme: defaultLightThemeData??ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Phone Validation'),
      )
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class PhoneValidationRecord {
  PhoneValidationRecord(this.areaCode, this.phoneNo, this.valid);
  
  final List<String> areaCode;
  final String phoneNo;
  final bool valid;

  @override
  String toString() {
    return '${areaCode[0]} $phoneNo is ${valid ? '' : 'not '}a valid phone number';
  }
}

class _MyHomePageState extends State<MyHomePage> {
  List<List<String>> _areaCollections = [];
  List<PhoneValidationRecord> validateHistory = [];
  List<String> selectedArea;

  final FocusNode _focusNode = FocusNode();
  TextEditingController phoneInputController = TextEditingController();

  bool showErrorMsg = false;

  // Fetch content from local bundled json file
  Future<void> readJson() async {
    final String response = await rootBundle.loadString('assets/area_codes_2DArray.json');
    final data = await json.decode(response);
    if (data is List) {
      setState(() {
          _areaCollections = data.map((e) {
            if (e is List)
              return e.map((e) => e as String).toList();
            else return [""];
          }).toList();
      });
    }
  }

  final Future<String> Function() canGetDefaultAreaByUserLocation = () async => Future.value(DEFAULT_AREA);

  @override
  void initState() {
    super.initState();
    readJson().then((value) async {
      final _defaultAreaByUserLocation = await canGetDefaultAreaByUserLocation();
      setState(() => selectedArea = _areaCollections.singleWhere((e) => e[2].toUpperCase() == _defaultAreaByUserLocation.toUpperCase()));
    });
    FlutterLibphonenumber().init();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) return;
      
      // only if the responder loses its focus
      if (!_focusNode.hasFocus) {
        print((selectedArea[0] ?? 'ERROR:MISSING_AREA_CODE') + phoneInputController.text);
        if (phoneInputController.text.isNotEmpty) validatePhoneNo();
      }
    });

  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        alignment: Alignment(0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListTile(
              onTap: () async {
                final _selectedAreaResult = await navigateToAreaSelectionPageAndCanGetSelectedArea();

                if (_selectedAreaResult != null) setState(() {
                  selectedArea = _selectedAreaResult;
                  showErrorMsg = false;
                });
              }, 
              leading: Text(selectedArea != null ? "${selectedArea[1]} ${selectedArea[0]}" : ''),
              title: TextFormField(
                controller: phoneInputController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                onChanged: (e) => setState((){showErrorMsg = false;}), 
                onFieldSubmitted: (e) => validatePhoneNo,
                decoration: InputDecoration(suffixIcon: IconButton(icon: Icon(Icons.close_rounded), onPressed: () {
                  phoneInputController.clear();
                  phoneInputController.clearComposing();
                  setState((){showErrorMsg = false;});
                })),
              ),
            ),
            CupertinoButton(onPressed: phoneInputController.text.length <= 0 ? null : validatePhoneNo, child: Text('Submit')),
            Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text(showErrorMsg ? 'Invalid Phone Number \"${selectedArea[0]} ${phoneInputController.text}\"' : '', style: TextStyle(color: Theme.of(context).colorScheme.error)))
          ],
        ),
      ),
    );
  }

  Future<List<String>> navigateToAreaSelectionPageAndCanGetSelectedArea() async {
    final _textEditingController = TextEditingController();
    final _selectedAreaResult = await Navigator.of(context).push<List<String>>(PageRouteBuilder(opaque: false, fullscreenDialog: true, pageBuilder: (_ctx, a, b) => Scaffold(
      appBar: AppBar(actions: [], backgroundColor: Colors.transparent, shadowColor: Colors.transparent,),
      backgroundColor: Colors.black54,
      body: Container(
        padding: EdgeInsets.only(top: 10),
        decoration: BoxDecoration(color: Theme.of(context).backgroundColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
        child: StatefulBuilder(builder: (_statefulBuilderCtx, _setState) {
          final _areas = _textEditingController.text.isNotEmpty ? _areaCollections.where((element) => element.join(' ').toUpperCase().contains(_textEditingController.text.toUpperCase())).toList() : _areaCollections;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(height: 0,),
            ListTile(title: TextField(
              controller: _textEditingController, 
              decoration: InputDecoration(labelText: 'Area filter:', floatingLabelBehavior: FloatingLabelBehavior.always, hintText: 'Type here to quickly find an area', helperText: 'e.g. +852 / HK / Hong Kong / 🇭🇰'), 
              onSubmitted: (e) { if( _areas.length == 1 ) Navigator.of(_ctx).pop(_areas[0]); }, 
              onChanged: (s) => _setState(() {}),
            )),
            if (_areas.length == 0) ListTile(title: Text('No matches for \"${_textEditingController.text}\"', textAlign: TextAlign.center,)),
            Expanded(child: ListView.builder(
              padding: EdgeInsets.zero.copyWith(bottom: MediaQuery.of(context).padding.bottom),
              itemCount: _areas.length,
              itemBuilder: (_itemBuilderCtx, i) => ListTile(
                onTap: () => Navigator.of(_itemBuilderCtx).pop(_areas[i]),
                title: Row(children: [
                  Flexible(flex: 2, fit: FlexFit.tight, child: Text("${_areas[i][1]}", textScaleFactor: 2,)),
                  Flexible(flex: 2, fit: FlexFit.tight, child: Text("${_areas[i][0]}")),
                  Flexible(flex: 7, child: Text("${_areas[i][3]}")),
                ])
              ),
            )),
          ]);
        }),
      ))
    ));
    return _selectedAreaResult;
  }

  Future<Map<String, dynamic>> canValidatePhoneNumber() async {
    final Map<String, dynamic> validateResultMap = await FlutterLibphonenumber().parse('${selectedArea[0]}${phoneInputController.text?.trim()}',);
    return validateResultMap;
  }

  void navigateToValidationAttemptsHistory() {
    final phoneValidationRecords = this.validateHistory.reversed.toList();
    Navigator.of(context).push(PageRouteBuilder(opaque: false, fullscreenDialog: true, pageBuilder: (_ctx, a, b) => Scaffold(
      appBar: AppBar(title: Text('History of Attempts'), leading: IconButton(icon: Icon(Icons.arrow_back_ios), onPressed: () => Navigator.of(_ctx).pop())),
      body: Stack(
        children: [
          ListView.builder(
            padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(context).padding.bottom),
            itemCount: phoneValidationRecords.length,
            itemBuilder: (_, i) => ListTile(
              title: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: (Theme.of(context).textTheme.bodyText1.color??Theme.of(context).iconTheme.color).withOpacity(.3), width: 1))), child: Row(children: [
                Flexible(flex: 2, fit: FlexFit.tight, child: Text("${phoneValidationRecords[i].areaCode[1]}", textScaleFactor: 2, textAlign: TextAlign.center)),
                Flexible(flex: 7, fit: FlexFit.tight, child: Text("${phoneValidationRecords[i].areaCode[0]} ${phoneValidationRecords[i].phoneNo}")),
                Flexible(flex: 1, fit: FlexFit.tight, child: Icon( phoneValidationRecords[i].valid ? Icons.check : Icons.close, color: phoneValidationRecords[i].valid ? AppUIColor.green : AppUIColor.red,)),
              ])),
            ),
          ),
          Positioned(left: 0, top: 0, right: 0, child: Container(
            height: 28, 
            padding: EdgeInsets.only(top: 4), 
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Theme.of(context).canvasColor, Theme.of(context).scaffoldBackgroundColor.withOpacity(0)])), 
            child: Text('Reverse Chronological Order', style: TextStyle(color: Theme.of(context).textTheme.bodyText1.color.withOpacity(.3)), textAlign: TextAlign.center,)
          )),
        ]
      )
    )));
  }

  void validationSucceed() {
    phoneInputController.clear();
    setState(() {});
    navigateToValidationAttemptsHistory();
  }

  Future<void> validatePhoneNo() async {
    final isValidResult = await canValidatePhoneNumber().catchError((e) { setState(() { showErrorMsg = true; }); });
    validateHistory = [...validateHistory, PhoneValidationRecord(selectedArea, isValidResult == null ? phoneInputController.text?.trim() : isValidResult['national'], isValidResult != null)];
    if (isValidResult != null) {
      validationSucceed();
    } else if (isValidResult == null) {
      setState(() => showErrorMsg = true);
    }
  }
}
