import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:skribbl/models/touch_points.dart';

class MyCustomPainter extends CustomPainter {
  List<TouchPoints> pointList;
  List<Offset> offsetPoints = [];
  MyCustomPainter({required this.pointList});

  @override
  void paint(Canvas canvas, Size size) {
    Paint background = Paint()..color = Colors.white;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    RRect rrect = RRect.fromRectAndCorners(rect);
    canvas.drawRRect(rrect, background);
    canvas.clipRRect(rrect);

    //Logic for points if there is a point
    //draw lines if there are a lot of points
    for (int i = 0; i < pointList.length - 1; i++) {
      if (pointList[i + 1] != null) {
        canvas.drawLine(
            pointList[i].points, pointList[i + 1].points, pointList[i].paint);
      } else if (pointList[i] != null && pointList[i + 1] == null) {
        //this is a point
        offsetPoints.clear();
        offsetPoints.add(pointList[i].points);
        offsetPoints.add(
            Offset(pointList[i].points.dx + 0.1, pointList[i].points.dy + 0.1));
        canvas.drawPoints(
            ui.PointMode.points, offsetPoints, pointList[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
