import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/widgets/trip_playback_dialog.dart';

void main() {
  testWidgets('TripPlaybackDialog pumps, plays, scrubs, and disposes without crashing', (tester) async {
    const trip = TripRecord(
      reference: 'TRIP-2026-083',
      tripNumber: 'TRIP-2026-083',
      origin: 'RBC SALON FURNITURE, Jolwa (21.17065, 73.00425)',
      destination: 'Mota, Bardoli Taluka (21.174901, 73.052134)',
      assignedVehicle: 'GJ19Y2720',
      assignedDriver: 'Sandeep',
      status: 'completed',
      actualDistanceKm: 5.8,
      plannedDistanceKm: 5.8,
      plannedDurationMinutes: 15,
      averageSpeedKmh: 23.2,
    );

    final controller = PlannerController();
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: TripPlaybackDialog(
          trip: trip,
          controller: controller,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog renders
    expect(find.byType(TripPlaybackDialog), findsOneWidget);

    // Tap Play button
    final playBtn = find.byIcon(Icons.play_arrow_rounded);
    if (playBtn.evaluate().isNotEmpty) {
      await tester.tap(playBtn);
      await tester.pump();
    }

    // Advance 5 seconds of playback
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Try scrubber
    final slider = find.byType(Slider);
    if (slider.evaluate().isNotEmpty) {
      await tester.drag(slider, const Offset(50, 0));
      await tester.pump();
    }

    // Tap speed button
    final speed2x = find.text('2x');
    if (speed2x.evaluate().isNotEmpty) {
      await tester.tap(speed2x);
      await tester.pump();
    }

    // Fast Forward & Rewind
    final fwdBtn = find.byIcon(Icons.forward_10_rounded);
    if (fwdBtn.evaluate().isNotEmpty) {
      await tester.tap(fwdBtn);
      await tester.pump();
    }
    final rwdBtn = find.byIcon(Icons.replay_10_rounded);
    if (rwdBtn.evaluate().isNotEmpty) {
      await tester.tap(rwdBtn);
      await tester.pump();
    }

    // Rapid speed switching
    for (final sp in ['1x', '2x', '5x', '10x']) {
      final btn = find.text(sp);
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Rapid dragging
    if (slider.evaluate().isNotEmpty) {
      for (double dx = -60; dx <= 60; dx += 20) {
        await tester.drag(slider, Offset(dx, 0));
        await tester.pump();
      }
    }

    // Finish while playing at 10x speed to ensure safe tear-down
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('TripPlaybackDialog handles long trips with stops and satellite toggle', (tester) async {
    const longTrip = TripRecord(
      reference: 'TRIP-2026-090',
      tripNumber: 'TRIP-2026-090',
      origin: 'Surat, Gujarat (21.1702, 72.8311)',
      destination: 'Mumbai, Maharashtra (19.0760, 72.8777)',
      assignedVehicle: 'GJ19Y2720',
      assignedDriver: 'Sandeep',
      status: 'completed',
      actualDistanceKm: 280.0,
      plannedDistanceKm: 280.0,
      plannedDurationMinutes: 300,
      averageSpeedKmh: 56.0,
    );

    final controller = PlannerController();
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: TripPlaybackDialog(
          trip: longTrip,
          controller: controller,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Toggle satellite style
    final satBtn = find.byTooltip('Toggle Satellite');
    if (satBtn.evaluate().isNotEmpty) {
      await tester.tap(satBtn);
      await tester.pump();
      await tester.tap(satBtn);
      await tester.pump();
    }

    // Tap fullscreen/fit button
    final fitBtn = find.byIcon(Icons.fullscreen_rounded);
    if (fitBtn.evaluate().isNotEmpty) {
      await tester.tap(fitBtn);
      await tester.pump();
    }

    // Start playback on long trip
    final playBtn = find.byIcon(Icons.play_arrow_rounded);
    if (playBtn.evaluate().isNotEmpty) {
      await tester.tap(playBtn);
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pump(const Duration(milliseconds: 500));
  });
}
