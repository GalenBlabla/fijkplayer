part of fijkplayer;

FijkPanelWidgetBuilder fijkPanel2Builder(
    {Key? key,
    final bool fill = false,
    final int duration = 4000,
    final bool doubleTap = true,
    final bool snapShot = false,
    final VoidCallback? onBack}) {
  return (FijkPlayer player, FijkData data, BuildContext context, Size viewSize,
      Rect texturePos) {
    return _FijkPanel2(
      key: key,
      player: player,
      data: data,
      onBack: onBack,
      viewSize: viewSize,
      texPos: texturePos,
      fill: fill,
      doubleTap: doubleTap,
      snapShot: snapShot,
      hideDuration: duration,
    );
  };
}

class _FijkPanel2 extends StatefulWidget {
  final FijkPlayer player;
  final FijkData data;
  final VoidCallback? onBack;
  final Size viewSize;
  final Rect texPos;
  final bool fill;
  final bool doubleTap;
  final bool snapShot;
  final int hideDuration;

  const _FijkPanel2(
      {Key? key,
      required this.player,
      required this.data,
      this.fill = false,
      this.onBack,
      required this.viewSize,
      this.hideDuration = 4000,
      this.doubleTap = false,
      this.snapShot = false,
      required this.texPos})
      : assert(hideDuration > 0 && hideDuration < 10000),
        super(key: key);

  @override
  __FijkPanel2State createState() => __FijkPanel2State();
}

class __FijkPanel2State extends State<_FijkPanel2> {
  FijkPlayer get player => widget.player;

  Timer? _hideTimer;
  bool _hideStuff = true;

  Timer? _statelessTimer;
  bool _prepared = false;
  bool _playing = false;
  bool _dragLeft = false;
  double? _volume;
  double? _brightness;
  OverlayEntry? _overlayEntry;
  double _seekPos = -1.0;
  Duration _duration = Duration();
  Duration _currentPos = Duration();
  Duration _bufferPos = Duration();

  StreamSubscription? _currentPosSubs;
  StreamSubscription? _bufferPosSubs;

  late StreamController<double> _valController;

  // snapshot
  ImageProvider? _imageProvider;
  Timer? _snapshotTimer;

  // Is it needed to clear seek data in FijkData (widget.data)
  bool _needClearSeekData = true;

  static const FijkSliderColors sliderColors = FijkSliderColors(
      cursorColor: Color.fromARGB(240, 250, 100, 10),
      playedColor: Color.fromARGB(200, 240, 90, 50),
      baselineColor: Color.fromARGB(100, 20, 20, 20),
      bufferedColor: Color.fromARGB(180, 200, 200, 200));

  @override
  void initState() {
    super.initState();

    _valController = StreamController.broadcast();
    _prepared = player.state.index >= FijkState.prepared.index;
    _playing = player.state == FijkState.started;
    _duration = player.value.duration;
    _currentPos = player.currentPos;
    _bufferPos = player.bufferPos;

    _currentPosSubs = player.onCurrentPosUpdate.listen((v) {
      if (_hideStuff == false) {
        setState(() {
          _currentPos = v;
        });
      } else {
        _currentPos = v;
      }
      if (_needClearSeekData) {
        widget.data.clearValue(FijkData._fijkViewPanelSeekto);
      }
      _needClearSeekData = false;
    });

    if (widget.data.contains(FijkData._fijkViewPanelSeekto)) {
      var pos = widget.data.getValue(FijkData._fijkViewPanelSeekto) as double;
      _currentPos = Duration(milliseconds: pos.toInt());
    }

    _bufferPosSubs = player.onBufferPosUpdate.listen((v) {
      if (_hideStuff == false) {
        setState(() {
          _bufferPos = v;
        });
      } else {
        _bufferPos = v;
      }
    });

    player.addListener(_playerValueChanged);
  }

  @override
  void dispose() {
    super.dispose();
    _valController.close();
    _hideTimer?.cancel();
    _statelessTimer?.cancel();
    _snapshotTimer?.cancel();
    _currentPosSubs?.cancel();
    _bufferPosSubs?.cancel();
    player.removeListener(_playerValueChanged);
  }

  double dura2double(Duration d) {
    return d.inMilliseconds.toDouble();
  }

  void _playerValueChanged() {
    FijkValue value = player.value;

    if (value.duration != _duration) {
      if (_hideStuff == false) {
        setState(() {
          _duration = value.duration;
        });
      } else {
        _duration = value.duration;
      }
    }
    bool playing = (value.state == FijkState.started);
    bool prepared = value.prepared;
    if (playing != _playing ||
        prepared != _prepared ||
        value.state == FijkState.asyncPreparing) {
      setState(() {
        _playing = playing;
        _prepared = prepared;
      });
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(milliseconds: widget.hideDuration), () {
      setState(() {
        _hideStuff = true;
      });
    });
  }

  void onTapFun() {
    if (_hideStuff == true) {
      _restartHideTimer();
    }
    setState(() {
      _hideStuff = !_hideStuff;
    });
  }

  void playOrPause() {
    if (player.isPlayable() || player.state == FijkState.asyncPreparing) {
      if (player.state == FijkState.started) {
        player.pause();
        _showOverlayMessage("Paused"); // 显示暂停提示
      } else {
        player.start();
        _showOverlayMessage("Playing"); // 显示播放提示
      }
    } else if (player.state == FijkState.initialized) {
      player.start();
      _showOverlayMessage("Playing"); // 显示播放提示
    } else {
      FijkLog.w("Invalid state ${player.state} ,can't perform play or pause");
    }
  }

  void onDoubleTapFun() {
    playOrPause();
  }

  void onVerticalDragStartFun(DragStartDetails d) {
    if (d.localPosition.dx > panelWidth() / 2) {
      // right, volume
      _dragLeft = false;
      FijkVolume.getVol().then((v) {
        if (!widget.data.contains(FijkData._fijkViewPanelVolume)) {
          widget.data.setValue(FijkData._fijkViewPanelVolume, v);
        }
        setState(() {
          _volume = v;
          _valController.add(v);
        });
      });
    } else {
      // left, brightness
      _dragLeft = true;
      FijkPlugin.screenBrightness().then((v) {
        if (!widget.data.contains(FijkData._fijkViewPanelBrightness)) {
          widget.data.setValue(FijkData._fijkViewPanelBrightness, v);
        }
        setState(() {
          _brightness = v;
          _valController.add(v);
        });
      });
    }
    _statelessTimer?.cancel();
    _statelessTimer = Timer(const Duration(milliseconds: 2000), () {
      setState(() {});
    });
  }

  void onVerticalDragUpdateFun(DragUpdateDetails d) {
    double delta = d.primaryDelta! / panelHeight();
    delta = -delta.clamp(-1.0, 1.0);
    if (_dragLeft == false) {
      var volume = _volume;
      if (volume != null) {
        volume += delta;
        volume = volume.clamp(0.0, 1.0);
        _volume = volume;
        FijkVolume.setVol(volume);
        setState(() {
          _valController.add(volume!);
        });
      }
    } else if (_dragLeft == true) {
      var brightness = _brightness;
      if (brightness != null) {
        brightness += delta;
        brightness = brightness.clamp(0.0, 1.0);
        _brightness = brightness;
        FijkPlugin.setScreenBrightness(brightness);
        setState(() {
          _valController.add(brightness!);
        });
      }
    }
  }

  void onVerticalDragEndFun(DragEndDetails e) {
    _volume = null;
    _brightness = null;
  }
  void _seekForward() {
    final currentPosition = player.currentPos;
    final newPosition = currentPosition + Duration(seconds: 10);
    if (newPosition <= _duration) {
      player.seekTo(newPosition.inMilliseconds);
      setState(() {
        _currentPos = newPosition;
      });
      _showOverlayMessage("+10s"); // 显示快进提示
    }
  }

  void _seekBackward() {
    final currentPosition = player.currentPos;
    final newPosition = currentPosition - Duration(seconds: 10);
    if (newPosition >= Duration.zero) {
      player.seekTo(newPosition.inMilliseconds);
      setState(() {
        _currentPos = newPosition;
      });
      _showOverlayMessage("-10s"); // 显示快退提示
    }
  }

  void _showOverlayMessage(String message) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: widget.viewSize.height / 2 - 50,
        left: widget.viewSize.width / 2 - 50,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(_overlayEntry!);

    // 在1秒后移除提示信息
    Future.delayed(Duration(seconds: 1), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }
  void _startSpeedUp() {
    player.setSpeed(2.0); // 设置倍速播放速度为2倍
    _showOverlayMessage("2x Speed"); // 显示倍速播放提示
  }

  void _resetSpeed() {
    player.setSpeed(1.0); // 恢复正常速度
    _showOverlayMessage("Normal Speed"); // 显示恢复正常速度提示
  }
  Widget buildPlayButton(BuildContext context, double height) {
    Icon icon = (player.state == FijkState.started)
        ? Icon(Icons.pause)
        : Icon(Icons.play_arrow);
    bool fullScreen = player.value.fullScreen;
    return IconButton(
      padding: EdgeInsets.all(0),
      iconSize: fullScreen ? height : height * 0.8,
      color: Color(0xFFFFFFFF),
      icon: icon,
      onPressed: playOrPause,
    );
  }

  Widget buildFullScreenButton(BuildContext context, double height) {
    Icon icon = player.value.fullScreen
        ? Icon(Icons.fullscreen_exit)
        : Icon(Icons.fullscreen);
    bool fullScreen = player.value.fullScreen;
    return IconButton(
      padding: EdgeInsets.all(0),
      iconSize: fullScreen ? height : height * 0.8,
      color: Color(0xFFFFFFFF),
      icon: icon,
      onPressed: () {
        player.value.fullScreen
            ? player.exitFullScreen()
            : player.enterFullScreen();
      },
    );
  }

  Widget buildTimeText(BuildContext context, double height) {
    String text =
        "${_duration2String(_currentPos)}" + "/${_duration2String(_duration)}";
    return Text(text, style: TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)));
  }

  Widget buildSlider(BuildContext context) {
    double duration = dura2double(_duration);

    double currentValue = _seekPos > 0 ? _seekPos : dura2double(_currentPos);
    currentValue = currentValue.clamp(0.0, duration);

    double bufferPos = dura2double(_bufferPos);
    bufferPos = bufferPos.clamp(0.0, duration);

    return Padding(
      padding: EdgeInsets.only(left: 3),
      child: FijkSlider(
        colors: sliderColors,
        value: currentValue,
        cacheValue: bufferPos,
        min: 0.0,
        max: duration,
        onChanged: (v) {
          _restartHideTimer();
          setState(() {
            _seekPos = v;
          });
        },
        onChangeEnd: (v) {
          setState(() {
            player.seekTo(v.toInt());
            _currentPos = Duration(milliseconds: _seekPos.toInt());
            widget.data.setValue(FijkData._fijkViewPanelSeekto, _seekPos);
            _needClearSeekData = true;
            _seekPos = -1.0;
          });
        },
      ),
    );
  }

  Widget buildBottom(BuildContext context, double height) {
    if (_duration.inMilliseconds > 0) {
      return Row(
        children: <Widget>[
          buildPlayButton(context, height),
          buildTimeText(context, height),
          Expanded(child: buildSlider(context)),
          buildFullScreenButton(context, height),
        ],
      );
    } else {
      return Row(
        children: <Widget>[
          buildPlayButton(context, height),
          Expanded(child: Container()),
          buildFullScreenButton(context, height),
        ],
      );
    }
  }

  void takeSnapshot() {
    player.takeSnapShot().then((v) {
      var provider = MemoryImage(v);
      precacheImage(provider, context).then((_) {
        setState(() {
          _imageProvider = provider;
        });
      });
      FijkLog.d("get snapshot succeed");
    }).catchError((e) {
      FijkLog.d("get snapshot failed");
    });
  }

  Widget buildPanel(BuildContext context) {
    double height = panelHeight();

    bool fullScreen = player.value.fullScreen;
    Widget centerWidget = Container(
      color: Color(0x00000000),
    );

    Widget centerChild = Container(
      color: Color(0x00000000),
    );

    if (fullScreen && widget.snapShot) {
      centerWidget = Row(
        children: <Widget>[
          Expanded(child: centerChild),
          Padding(
            padding: EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(
                  padding: EdgeInsets.all(0),
                  color: Color(0xFFFFFFFF),
                  icon: Icon(Icons.camera_alt),
                  onPressed: () {
                    takeSnapshot();
                  },
                ),
              ],
            ),
          )
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: height > 200 ? 80 : height / 5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x88000000), Color(0x00000000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Expanded(
          child: centerWidget,
        ),
        Container(
          height: height > 80 ? 80 : height / 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x88000000), Color(0x00000000)],
              end: Alignment.topCenter,
              begin: Alignment.bottomCenter,
            ),
          ),
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height > 80 ? 45 : height / 2,
            padding: EdgeInsets.only(left: 8, right: 8, bottom: 5),
            child: buildBottom(context, height > 80 ? 40 : height / 2),
          ),
        )
      ],
    );
  }
  String _formatDuration(Duration position) {
    int minutes = position.inMinutes;
    int seconds = position.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCurrentTimeLabel() {
    if (_seekPos > 0) {
      Duration position = Duration(milliseconds: _seekPos.toInt());
      return Positioned(
        top: 10,
        left: MediaQuery.of(context).size.width / 2 - 50,
        child: Container(
          padding: EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '${_formatDuration(position)} / ${_formatDuration(_duration)}',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } else {
      return Container();
    }
  }
  GestureDetector buildGestureDetector(BuildContext context) {
    return GestureDetector(
      onTap: onTapFun,
      onDoubleTapDown: (details) {
        // 获取点击的位置
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dx = details.globalPosition.dx;

        if (dx < screenWidth / 3) {
          // 左边三分之一屏幕，快退10秒
          _seekBackward();
        } else if (dx > 2 * screenWidth / 3) {
          // 右边三分之一屏幕，快进10秒
          _seekForward();
        } else {
          // 中间三分之一屏幕，暂停/播放
          playOrPause();
        }
      },
      onVerticalDragUpdate: onVerticalDragUpdateFun,
      onVerticalDragStart: onVerticalDragStartFun,
      onVerticalDragEnd: onVerticalDragEndFun,
      onHorizontalDragStart: (d) {
        // 保存当前播放位置，用于计算拖动后的播放位置
        _seekPos = _currentPos.inMilliseconds.toDouble();
      },
      onHorizontalDragUpdate: (d) {
        double delta = d.primaryDelta! / panelWidth() * dura2double(_duration);
        setState(() {
          _seekPos = (_seekPos + delta).clamp(0.0, dura2double(_duration));
          player.seekTo(_seekPos.toInt());
        });
      },
      onHorizontalDragEnd: (d) {
        // 拖动结束后更新当前播放位置并清除 _seekPos
        setState(() {
          _currentPos = Duration(milliseconds: _seekPos.toInt());
          _seekPos = -1.0;
        });
      },
      onLongPressStart: (details) {
        _startSpeedUp();
      },
      onLongPressEnd: (details) {
        _resetSpeed();
      },
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: _hideStuff,
            child: AnimatedOpacity(
              opacity: _hideStuff ? 0 : 1,
              duration: Duration(milliseconds: 300),
              child: buildPanel(context),
            ),
          ),
          _buildCurrentTimeLabel(), // 在屏幕上显示当前时间
        ],
      ),
    );
  }

  Rect panelRect() {
    Rect rect = player.value.fullScreen || (true == widget.fill)
        ? Rect.fromLTWH(0, 0, widget.viewSize.width, widget.viewSize.height)
        : Rect.fromLTRB(
            max(0.0, widget.texPos.left),
            max(0.0, widget.texPos.top),
            min(widget.viewSize.width, widget.texPos.right),
            min(widget.viewSize.height, widget.texPos.bottom));
    return rect;
  }

  double panelHeight() {
    if (player.value.fullScreen || (true == widget.fill)) {
      return widget.viewSize.height;
    } else {
      return min(widget.viewSize.height, widget.texPos.bottom) -
          max(0.0, widget.texPos.top);
    }
  }

  double panelWidth() {
    if (player.value.fullScreen || (true == widget.fill)) {
      return widget.viewSize.width;
    } else {
      return min(widget.viewSize.width, widget.texPos.right) -
          max(0.0, widget.texPos.left);
    }
  }

  Widget buildBack(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.only(left: 5),
      icon: Icon(
        Icons.arrow_back_ios,
        color: Color(0xDDFFFFFF),
      ),
      onPressed: widget.onBack,
    );
  }

  Widget buildStateless() {
    var volume = _volume;
    var brightness = _brightness;
    if (volume != null || brightness != null) {
      Widget toast = volume == null
          ? defaultFijkBrightnessToast(brightness!, _valController.stream)
          : defaultFijkVolumeToast(volume, _valController.stream);
      return IgnorePointer(
        child: AnimatedOpacity(
          opacity: 1,
          duration: Duration(milliseconds: 500),
          child: toast,
        ),
      );
    } else if (player.state == FijkState.asyncPreparing) {
      return Container(
        alignment: Alignment.center,
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white)),
        ),
      );
    } else if (player.state == FijkState.error) {
      return Container(
        alignment: Alignment.center,
        child: Icon(
          Icons.error,
          size: 30,
          color: Color(0x99FFFFFF),
        ),
      );
    } else if (_imageProvider != null) {
      _snapshotTimer?.cancel();
      _snapshotTimer = Timer(Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _imageProvider = null;
          });
        }
      });
      return Center(
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.yellowAccent, width: 3)),
            child:
                Image(height: 200, fit: BoxFit.contain, image: _imageProvider!),
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    Rect rect = panelRect();

    List ws = <Widget>[];

    if (_statelessTimer != null && _statelessTimer!.isActive) {
      ws.add(buildStateless());
    } else if (player.state == FijkState.asyncPreparing) {
      ws.add(buildStateless());
    } else if (player.state == FijkState.error) {
      ws.add(buildStateless());
    } else if (_imageProvider != null) {
      ws.add(buildStateless());
    }
    ws.add(buildGestureDetector(context));
    if (widget.onBack != null) {
      ws.add(buildBack(context));
    }
    return Positioned.fromRect(
      rect: rect,
      child: Stack(children: ws as List<Widget>),
    );
  }
}
