import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/workout.dart';

class ExerciseCard extends StatefulWidget {
  final String exerciseName;
  final List<SetLog> sets;
  final List<SetLog>? lastSessionSets;
  final VoidCallback onAddSet;
  final Function(int index, String field, dynamic value) onUpdateSet;
  final Function(int index) onDeleteSet;
  final bool isCardio;

  const ExerciseCard({
    super.key,
    required this.exerciseName,
    required this.sets,
    this.lastSessionSets,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onDeleteSet,
    this.isCardio = false,
  });

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  final List<TextEditingController> _weightControllers = [];
  final List<TextEditingController> _repsControllers = [];

  TextEditingController? _sprintDurationController;
  TextEditingController? _sprintSpeedController;
  TextEditingController? _runDurationController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCardio) {
      if (widget.sets.isNotEmpty) {
        final set = widget.sets.first;
        if (_sprintDurationController?.text != (set.sprintDuration ?? "")) {
          _sprintDurationController?.text = set.sprintDuration ?? "";
        }
        if (_sprintSpeedController?.text != (set.sprintSpeed ?? "")) {
          _sprintSpeedController?.text = set.sprintSpeed ?? "";
        }
        if (_runDurationController?.text != (set.runDuration ?? "")) {
          _runDurationController?.text = set.runDuration ?? "";
        }
      }
    } else {
      // Re-initialize if the number of sets changed
      if (oldWidget.sets.length != widget.sets.length) {
        _disposeControllers();
        _initControllers();
      } else {
        // Sync values if they were changed outside (e.g. copy)
        for (int i = 0; i < widget.sets.length; i++) {
          final wStr = widget.sets[i].weight > 0 ? widget.sets[i].weight.toStringAsFixed(0) : "";
          final rStr = widget.sets[i].reps > 0 ? widget.sets[i].reps.toString() : "";
          
          if (_weightControllers[i].text != wStr) {
            _weightControllers[i].text = wStr;
          }
          if (_repsControllers[i].text != rStr) {
            _repsControllers[i].text = rStr;
          }
        }
      }
    }
  }

  void _initControllers() {
    if (widget.isCardio) {
      final set = widget.sets.isNotEmpty ? widget.sets.first : SetLog(weight: 0, reps: 0);
      _sprintDurationController = TextEditingController(text: set.sprintDuration ?? "");
      _sprintSpeedController = TextEditingController(text: set.sprintSpeed ?? "");
      _runDurationController = TextEditingController(text: set.runDuration ?? "");
    } else {
      for (var set in widget.sets) {
        final weightVal = set.weight > 0 ? set.weight.toStringAsFixed(0) : "";
        final repsVal = set.reps > 0 ? set.reps.toString() : "";
        _weightControllers.add(TextEditingController(text: weightVal));
        _repsControllers.add(TextEditingController(text: repsVal));
      }
    }
  }

  void _disposeControllers() {
    _sprintDurationController?.dispose();
    _sprintSpeedController?.dispose();
    _runDurationController?.dispose();
    _sprintDurationController = null;
    _sprintSpeedController = null;
    _runDurationController = null;

    for (var controller in _weightControllers) {
      controller.dispose();
    }
    for (var controller in _repsControllers) {
      controller.dispose();
    }
    _weightControllers.clear();
    _repsControllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _copyPreviousSet(int index) {
    if (index > 0 && widget.sets[index - 1].completed) {
      final prev = widget.sets[index - 1];
      widget.onUpdateSet(index, 'weight', prev.weight);
      widget.onUpdateSet(index, 'reps', prev.reps);
    } else if (widget.lastSessionSets != null && widget.lastSessionSets!.length > index) {
      final prevSessionSet = widget.lastSessionSets![index];
      widget.onUpdateSet(index, 'weight', prevSessionSet.weight);
      widget.onUpdateSet(index, 'reps', prevSessionSet.reps);
    } else if (widget.lastSessionSets != null && widget.lastSessionSets!.isNotEmpty) {
      final prevSessionSet = widget.lastSessionSets!.first;
      widget.onUpdateSet(index, 'weight', prevSessionSet.weight);
      widget.onUpdateSet(index, 'reps', prevSessionSet.reps);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLastSession = widget.lastSessionSets != null && widget.lastSessionSets!.isNotEmpty;
    final lastSummary = hasLastSession
        ? widget.lastSessionSets!.map((s) => "${s.weight.toStringAsFixed(0)}kg x ${s.reps}").join(" | ")
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.35), // Gray-800
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.exerciseName,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.isCardio) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.15),
                              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Cardio",
                              style: GoogleFonts.inter(
                                color: const Color(0xFF60A5FA),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!widget.isCardio && hasLastSession) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Last: $lastSummary",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF60A5FA).withOpacity(0.85),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (widget.isCardio) ...[
            // Cardio layout
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sprint Duration",
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _sprintDurationController,
                            enabled: widget.sets.isNotEmpty && !widget.sets.first.completed,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "e.g. 55 sec",
                              hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFF030712).withOpacity(0.8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF374151)),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF1F2937)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF2563EB)),
                              ),
                            ),
                            onChanged: (val) {
                              widget.onUpdateSet(0, 'sprintDuration', val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sprint Speed",
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _sprintSpeedController,
                            enabled: widget.sets.isNotEmpty && !widget.sets.first.completed,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "e.g. 12 km/h",
                              hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFF030712).withOpacity(0.8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF374151)),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF1F2937)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF2563EB)),
                              ),
                            ),
                            onChanged: (val) {
                              widget.onUpdateSet(0, 'sprintSpeed', val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Run Time",
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _runDurationController,
                      enabled: widget.sets.isNotEmpty && !widget.sets.first.completed,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "e.g. 10 mins",
                        hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFF030712).withOpacity(0.8),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF374151)),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1F2937)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB)),
                        ),
                      ),
                      onChanged: (val) {
                        widget.onUpdateSet(0, 'runDuration', val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.sets.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          final set = widget.sets.first;
                          widget.onUpdateSet(0, 'completed', !set.completed);
                        },
                        icon: Icon(
                          widget.sets.first.completed ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          widget.sets.first.completed ? "Completed" : "Mark Complete",
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.sets.first.completed ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
              ],
            )
          ] else ...[
            // Column headers
            if (widget.sets.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  children: [
                    const SizedBox(width: 20, child: Text("#", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                    const Expanded(flex: 2, child: Center(child: Text("Target", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)))),
                    const Expanded(flex: 3, child: Center(child: Text("Weight", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)))),
                    const Expanded(flex: 3, child: Center(child: Text("Reps", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)))),
                    const Expanded(flex: 5, child: Center(child: Text("Actions", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // List of sets
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.sets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final set = widget.sets[index];
                final hasTarget = widget.lastSessionSets != null && widget.lastSessionSets!.length > index;
                final targetText = hasTarget
                    ? "${widget.lastSessionSets![index].weight.toStringAsFixed(0)}x${widget.lastSessionSets![index].reps}"
                    : "—";

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: set.completed
                        ? const Color(0xFF10B981).withOpacity(0.06)
                        : const Color(0xFF111827).withOpacity(0.4),
                    border: Border.all(
                      color: set.completed
                          ? const Color(0xFF10B981).withOpacity(0.25)
                          : const Color(0xFF374151).withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Index number
                      SizedBox(
                        width: 20,
                        child: Text(
                          "${index + 1}",
                          style: GoogleFonts.shareTechMono(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: set.completed ? const Color(0xFF10B981) : Colors.grey,
                          ),
                        ),
                      ),

                      // Target pill
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF374151).withOpacity(0.4)),
                            ),
                            child: Text(
                              targetText,
                              style: GoogleFonts.shareTechMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: hasTarget ? Colors.grey : Colors.grey.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Weight input field
                      Expanded(
                        flex: 3,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _weightControllers[index],
                            enabled: !set.completed,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.shareTechMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: hasTarget
                                  ? widget.lastSessionSets![index].weight.toStringAsFixed(0)
                                  : "0",
                              hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              filled: true,
                              fillColor: const Color(0xFF030712).withOpacity(0.8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF374151)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF2563EB)),
                              ),
                            ),
                            onChanged: (val) {
                              final w = double.tryParse(val) ?? 0.0;
                              widget.onUpdateSet(index, 'weight', w);
                            },
                          ),
                        ),
                      ),

                      // Reps input field
                      Expanded(
                        flex: 3,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _repsControllers[index],
                            enabled: !set.completed,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.shareTechMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: hasTarget
                                  ? widget.lastSessionSets![index].reps.toString()
                                  : "0",
                              hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              filled: true,
                              fillColor: const Color(0xFF030712).withOpacity(0.8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF374151)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF2563EB)),
                              ),
                            ),
                            onChanged: (val) {
                              final r = int.tryParse(val) ?? 0;
                              widget.onUpdateSet(index, 'reps', r);
                            },
                          ),
                        ),
                      ),

                      // Actions (Check off, Copy previous, Delete)
                      Expanded(
                        flex: 5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Checkoff
                            InkWell(
                              onTap: () {
                                final isCompleted = !set.completed;
                                widget.onUpdateSet(index, 'completed', isCompleted);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                decoration: BoxDecoration(
                                  color: set.completed ? const Color(0xFF10B981) : Colors.transparent,
                                  border: Border.all(
                                    color: set.completed ? const Color(0xFF10B981) : const Color(0xFF374151),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 14,
                                  color: set.completed ? Colors.white : Colors.transparent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            // Copy Helper
                            if (!set.completed)
                              InkWell(
                                onTap: () => _copyPreviousSet(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFF374151)),
                                    borderRadius: BorderRadius.circular(10),
                                    color: const Color(0xFF030712).withOpacity(0.4),
                                  ),
                                  child: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                                ),
                              ),
                            const SizedBox(width: 3),
                            // Delete
                            InkWell(
                              onTap: () => widget.onDeleteSet(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF374151)),
                                  borderRadius: BorderRadius.circular(10),
                                  color: const Color(0xFF030712).withOpacity(0.4),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Add set button
            ElevatedButton.icon(
              onPressed: widget.onAddSet,
              icon: const Icon(Icons.add, size: 14, color: Color(0xFF60A5FA)),
              label: Text("Add Set", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF60A5FA))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827).withOpacity(0.5),
                side: BorderSide(color: const Color(0xFF374151).withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          ],
        ],
      ),
    );
  }
}
