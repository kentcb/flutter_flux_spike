import 'dart:async';

import 'package:flutter_flux/flutter_flux.dart';
import 'package:flutter/material.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Repro',
      home: new MaterialApp(
          home: new Scaffold(
              body: new LoginPage())),
    );
  }
}

class User {
  // unimportant
}

class LoginApi {
  Future<User> authenticate(String user, String password) async {
    await new Future<dynamic>.delayed(
        new Duration(milliseconds: 1000));

    if (user.toLowerCase() == "u" && password.toLowerCase() == "p") {
      return new User();
    }

    throw new Exception("Auth failed");
  }
}

// store actions
final Action<String> modifyUser = new Action<String>();
final Action<String> modifyPassword = new Action<String>();
final Action<dynamic> instigateLogin = new Action<dynamic>();

enum _AuthenticationStatus {
  pending,
  authenticating,
  authenticationFailed,
  authenticationSucceeded
}

class LoginStore extends Store {
  final LoginApi _api;
  String _name;
  String _password;
  User _user;
  _AuthenticationStatus _status;

  LoginStore(this._api) {
    _status = _AuthenticationStatus.pending;

    triggerOnAction(modifyUser, (value) => _name = value);
    triggerOnAction(modifyPassword, (value) => _password = value);
    triggerOnAction(instigateLogin, (_) async => await _login());
  }

  String get name => _name;

  String get password => _password;

  User get user => _user;

  bool get isAuthenticating => _status == _AuthenticationStatus.authenticating;

  bool get isAuthenticated => _status == _AuthenticationStatus.authenticationSucceeded;

  bool get hasAuthenticationFailed => _status == _AuthenticationStatus.authenticationFailed;

  bool isUserValid() => _name != null && _name.length > 0;

  bool isPasswordValid() => _password != null && _password.length > 0;

  Future<dynamic> _login() async {
    if (!isUserValid() || !isPasswordValid()) {
      return Null;
    }

    _updateStatus(_AuthenticationStatus.authenticating);

    try {
      _user = await _api.authenticate(_name, _password);
      _updateStatus(_AuthenticationStatus.authenticationSucceeded);
    } catch (exception) {
      _updateStatus(_AuthenticationStatus.authenticationFailed);
    }
  }

  void _updateStatus(_AuthenticationStatus status) {
    _status = status;
    trigger();
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() =>
      new _LoginPageState(
        // TODO: is this the right place to create a store that has an external
        //       dependency? In my real app, the dependency will differ depending
        //       on the build configuration.
        new LoginStore(
          new LoginApi()));
}

class _LoginPageState extends State<LoginPage> with StoreWatcherMixin<LoginPage> {
  final LoginStore _store;
  final StoreToken _storeToken;
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  final TextEditingController _userTextEditingController = new TextEditingController();
  final TextEditingController _passwordTextEditingController = new TextEditingController();

  _LoginPageState(this._store) :
    _storeToken = new StoreToken(_store) {
  }

  @override
  void initState() {
    super.initState();

    listenToStore(_storeToken);
  }

  @override
  Widget build(BuildContext context) {
    if (_store.isAuthenticated) {
      // TODO: Is there a better way for me to trigger this? Bear in mind my
      //       real app shows LoginPage as a modal, so I definitely need to be
      //       able to pop it when authentication succeeds. This also triggers an
      //       assertion failure: 'setState() or markNeedsBuild() called during build.'
      Navigator
          .of(context)
          .pop(_store.name);

      // TODO: this is kinda weird, but I have to return _something_
      return new Text("");
    }

    final FocusNode userTextFieldFocusNode = new FocusNode();
    final FocusNode passwordTextFieldFocusNode = new FocusNode();

    var loginButton = new FlatButton(
      child: new Text("LOGIN"),
      onPressed: _store.isAuthenticating ? null : () async {

        // TODO: is this really the best way to do this?

        await modifyUser(_userTextEditingController.text);
        await modifyPassword(_passwordTextEditingController.text);

        final FormState formState = _formKey.currentState;

        if (!formState.validate()) {
          return;
        }

        await instigateLogin(null);
      },
    );

    var userTextField = new TextFormField(
      autocorrect: false,
      autofocus: true,
      controller: _userTextEditingController,
      decoration: new InputDecoration(
        helperText: 'Name',
      ),
      //enabled: !_store.isAuthenticating,
      focusNode: userTextFieldFocusNode,
      // TODO: why do I need this?
      initialValue: _userTextEditingController.text,
      onFieldSubmitted: (value) =>
          FocusScope
              .of(context)
              .requestFocus(passwordTextFieldFocusNode),
      validator: (_) => _store.isUserValid() ? null : "Please enter a name.",
    );

    var passwordTextField = new TextFormField(
      autocorrect: false,
      controller: _passwordTextEditingController,
      obscureText: true,
      decoration: new InputDecoration(
        helperText: 'Password',
      ),
      //enabled: !_store.isAuthenticating,
      focusNode: passwordTextFieldFocusNode,
      initialValue:
      _store.isAuthenticating ? _passwordTextEditingController.text : "",
      onFieldSubmitted: (value) => loginButton.onPressed(),
      validator: (_) => _store.isPasswordValid() ? null : "Please enter a password.",
    );

    var formChildren = <Widget>[
        new Container(
            padding: const EdgeInsets.only(top: 40.0),
            child: new Column(
                children: [
                  userTextField,
                  passwordTextField,
                  loginButton,
                ])),
      ];

    if (_store.hasAuthenticationFailed) {
      formChildren.add(new Text(
        "Please check your login details.",
      ));
    }

    var form = new Form(
      key: _formKey,
      child: new Column(children: formChildren),
    );

    return form;
  }
}
