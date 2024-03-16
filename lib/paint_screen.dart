import 'dart:async';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:skribbl/home_screen.dart';
import 'package:skribbl/models/touch_points.dart';
import 'package:skribbl/sidebar/player_scoreboard_drawer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'final_leaderboard_screen.dart';
import 'models/my_custom_painter.dart';
import 'waiting_lobby_screen.dart';

class PaintScreen extends StatefulWidget {
  final Map data;
  final String screenFrom;
  const PaintScreen({super.key, required this.data, required this.screenFrom});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  late IO.Socket _socket;
  Map dataOfRoom = {};
  List<TouchPoints> points = [];
  var selectedColor = Colors.black;
  double strokeWidth = 2.0;
  List<Widget> textBlankWidget = [];
  final ScrollController _scrollController = ScrollController();
  List<Map> message = [];
  final TextEditingController controller = TextEditingController();
  int guessedUserCtr = 0;
  int _start = 60;
  late Timer _timer;
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map> scoreBoard = [];
  bool isTextInputReadOnly = false;
  int maxPoints = 0;
  String winner = '';
  bool isShowFinalLeaderboard = false;

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        _socket.emit('change-turn', dataOfRoom['name']);
        setState(() {
          _timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void renderTextBlank(String text) {
    textBlankWidget.clear();
    for (int i = 0; i <= text.length; i++) {}
  }

  //for socket io connection
  void connect() {
    _socket = IO.io(
        'http://172.9.9.18:3000',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build());
    _socket.connect();

    //receiving
    _socket.onConnect((data) {
      _socket.on('updateRoom', (roomData) {
        setState(() {
          renderTextBlank(roomData['word']);
          dataOfRoom = roomData;
        });
        if (roomData['isJoin'] != true) {
          startTimer();
          scoreBoard.clear();
          for (int i = 0; i < roomData['players'].length; i++) {
            setState(() {
              scoreBoard.add({
                'username': roomData['players'][i]['nickname'],
                'points': roomData['players'][i]['points'].toString(),
              });
            });
          }
        }

        _socket.on(
            'notCorrectGame',
            (data) => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false));

        _socket.on('points', (point) {
          if (point['details'] != null) {
            setState(() {
              points.add(TouchPoints(
                  paint: Paint()
                    ..strokeCap = StrokeCap.round
                    ..isAntiAlias = true
                    ..color = selectedColor.withOpacity(1)
                    ..strokeWidth = strokeWidth,
                  points: Offset(double.parse(point['details']['dx']),
                      double.parse(point['details']['dy']))));
            });
          }
        });
      });
    });
    _socket.on('user-disconnected', (data) {
      scoreBoard.clear();
      for (int i = 0; i < data.length; i++) {
        setState(() {
          scoreBoard.add({
            'username': data[i]['nickname'],
            'points': data[i]['points'].toString(),
          });
        });
      }
    });

    if (widget.screenFrom == "createRoom") {
      _socket.emit('create-game', widget.data);
    } else {
      _socket.emit('join-game', widget.data);
    }

    _socket.on('msg', (msgData) {
      setState(() {
        message.add(msgData);
        guessedUserCtr = msgData['guesseduserCtr'];
      });
      if (guessedUserCtr == dataOfRoom['players'].length - 1) {
        _socket.emit('change-turn', dataOfRoom['name']);
      }
      _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 40,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut);
    });

    _socket.on('change-turn', (data) {
      String oldWord = dataOfRoom['word'];

      showDialog(
          context: context,
          builder: (context) {
            Future.delayed(const Duration(seconds: 3), () {
              setState(() {
                dataOfRoom = data;
                renderTextBlank(data['word']);
                isTextInputReadOnly = false;
                guessedUserCtr = 0;
                _start = 60;
                points.clear();
                _timer.cancel();
                startTimer();
              });
            });
            Navigator.of(context).pop();
            return AlertDialog(
              title: Center(
                child: Text("Word was $oldWord"),
              ),
            );
          });
    });

    _socket.on('updateScore', (roomData) {
      scoreBoard.clear();
      for (int i = 0; i < roomData['players'].length; i++) {
        setState(() {
          scoreBoard.add({
            'username': roomData['players'][i]['nickname'],
            'points': roomData['players'][i]['points'].toString()
          });
        });
      }
    });

    _socket.on('color-change', (colorString) {
      int value = int.parse(colorString, radix: 16);
      Color theColor = Color(value);
      setState(() {
        selectedColor = theColor;
      });
    });

    _socket.on('show-leaderboard', (roomPlayers) {
      scoreBoard.clear();
      for (int i = 0; i < roomPlayers.length; i++) {
        setState(() {
          scoreBoard.add({
            'username': roomPlayers[i]['nickname'],
            'points': roomPlayers[i]['points'].toString(),
          });
        });
        if (maxPoints < int.parse(scoreBoard[i]['points'])) {
          winner = scoreBoard[i]['username'];
          maxPoints = int.parse(scoreBoard[i]['points']);
        }
      }
      setState(() {
        _timer.cancel();
        isShowFinalLeaderboard = true;
      });
    });

    _socket.on('stroke-width', (value) {
      setState(() {
        strokeWidth = double.parse(value);
      });
    });

    _socket.on('clear-screen', (data) {
      setState(() {
        points.clear();
      });
    });

    _socket.on('closeInput', (_) {
      _socket.emit('updateScore', widget.data['name']);
      setState(() {
        isTextInputReadOnly = true;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    connect();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    void selectColor() {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Choose color'),
                content: SingleChildScrollView(
                  child: BlockPicker(
                    pickerColor: selectedColor,
                    onColorChanged: (color) {
                      String colorString = color.toString();
                      String valueString =
                          colorString.split('(0x')[1].split(')')[0];
                      Map map = {
                        'color': valueString,
                        'roomName': dataOfRoom['name']
                      };
                      _socket.emit('color-change', map);
                    },
                  ),
                ),
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Close'))
                ],
              ));
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: PlayerScore(userData: scoreBoard),
      body: dataOfRoom != null
          ? dataOfRoom['isJoin'] != true
              ? !isShowFinalLeaderboard
                  ? Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: width,
                              height: height * 0.55,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  _socket.emit('paint', {
                                    'details': {
                                      'dx': details.localPosition.dx,
                                      'dy': details.localPosition.dy
                                    },
                                    'roomName': widget.data['name'],
                                  });
                                },
                                onPanStart: (details) {
                                  _socket.emit('paint', {
                                    'details': {
                                      'dx': details.localPosition.dx,
                                      'dy': details.localPosition.dy
                                    },
                                    'roomName': widget.data['name'],
                                  });
                                },
                                onPanEnd: (details) {
                                  _socket.emit('paint', {
                                    'details': null,
                                    'roomName': widget.data['name'],
                                  });
                                },
                                child: SizedBox.expand(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(20)),
                                    child: CustomPaint(
                                      size: Size.infinite,
                                      painter:
                                          MyCustomPainter(pointList: points),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                    onPressed: () {
                                      selectColor();
                                    },
                                    icon: Icon(
                                      Icons.color_lens,
                                      color: selectedColor,
                                    )),
                                Expanded(
                                  child: Slider(
                                    min: 0.0,
                                    max: 1.0,
                                    label: 'Stroke Width $strokeWidth',
                                    activeColor: selectedColor,
                                    value: strokeWidth,
                                    onChanged: (value) {
                                      Map map = {
                                        'value': value,
                                        'roomName': widget.data['name']
                                      };
                                      _socket.emit('stroke-width', map);
                                    },
                                  ),
                                ),
                                IconButton(
                                    onPressed: () {
                                      _socket.emit(
                                          'clear-screen', widget.data['name']);
                                    },
                                    icon: Icon(
                                      Icons.layers_clear,
                                      color: selectedColor,
                                    )),
                              ],
                            ),
                            dataOfRoom['turn']['nickname'] !=
                                    widget.data['nickname']
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: textBlankWidget,
                                  )
                                : Center(
                                    child: Text(
                                      dataOfRoom['word'],
                                      style: const TextStyle(fontSize: 30),
                                    ),
                                  ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: ListView.builder(
                                  controller: _scrollController,
                                  shrinkWrap: true,
                                  itemCount: message.length,
                                  itemBuilder: (context, index) {
                                    var msg = message[index].values;
                                    return ListTile(
                                      title: Text(
                                        msg.elementAt(0),
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        msg.elementAt(1),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 16),
                                      ),
                                    );
                                  }),
                            ),
                          ],
                        ),
                        dataOfRoom['turn']['nickname'] !=
                                widget.data['nickname']
                            ? Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: TextField(
                                    readOnly: isTextInputReadOnly,
                                    controller: controller,
                                    autocorrect: false,
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        Map map = {
                                          'username': widget.data['nickName'],
                                          'msg': value.trim(),
                                          'word': dataOfRoom['word'],
                                          'roomName': widget.data['name'],
                                          'guessedUserCtr': guessedUserCtr,
                                          'totalTime': 60,
                                          'timeTaken': 60 - _start,
                                        };
                                        _socket.emit('msg', map);
                                        controller.clear();
                                      }
                                    },
                                    decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Colors.transparent),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Colors.transparent),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 14),
                                        filled: true,
                                        fillColor: const Color(0xffF5F5FA),
                                        hintText: 'Your Guess',
                                        hintStyle: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400)),
                                    textInputAction: TextInputAction.done,
                                  ),
                                ),
                              )
                            : const SizedBox(),
                        SafeArea(
                            child: IconButton(
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            scaffoldKey.currentState!.openDrawer();
                          },
                        ))
                      ],
                    )
                  : FinalLeaderBoard(
                      scoreboard: scoreBoard,
                      winner: winner,
                    )
              : WaitingLobbyScreen(
                  lobbyName: dataOfRoom['name'],
                  noOfPlayer: dataOfRoom['players'].length,
                  occupancy: dataOfRoom['occupancy'],
                )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 30),
        child: FloatingActionButton(
          onPressed: () {},
          elevation: 7,
          backgroundColor: Colors.white,
          child: Text(
            "$_start",
            style: const TextStyle(color: Colors.black, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
