enum SavingGoalStatus { pending, achieved }

class SavingGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double contributionPerCycle;
  final double savedAmount;
  final DateTime createdAt;
  final List<String> processedCycleIds;
  final SavingGoalStatus status;

  const SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.contributionPerCycle,
    required this.savedAmount,
    required this.createdAt,
    this.processedCycleIds = const [],
    this.status = SavingGoalStatus.pending,
  });

    double get remainingAmount =>
      (targetAmount - savedAmount).clamp(0, targetAmount).toDouble();

    double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1).toDouble();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'contributionPerCycle': contributionPerCycle,
        'savedAmount': savedAmount,
        'createdAt': createdAt.toIso8601String(),
        'processedCycleIds': processedCycleIds,
        'status': status.name,
      };

  factory SavingGoal.fromMap(Map<String, dynamic> map) => SavingGoal(
        id: map['id'] as String,
        name: map['name'] as String,
        targetAmount: (map['targetAmount'] as num).toDouble(),
        contributionPerCycle: (map['contributionPerCycle'] as num).toDouble(),
        savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(map['createdAt'] as String),
        processedCycleIds: List<String>.from(map['processedCycleIds'] as List<dynamic>? ?? const []),
        status: SavingGoalStatus.values.firstWhere(
          (status) => status.name == map['status'],
          orElse: () => SavingGoalStatus.pending,
        ),
      );

  SavingGoal copyWith({
    String? name,
    double? targetAmount,
    double? contributionPerCycle,
    double? savedAmount,
    List<String>? processedCycleIds,
    SavingGoalStatus? status,
  }) =>
      SavingGoal(
        id: id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        contributionPerCycle: contributionPerCycle ?? this.contributionPerCycle,
        savedAmount: savedAmount ?? this.savedAmount,
        createdAt: createdAt,
        processedCycleIds: processedCycleIds ?? this.processedCycleIds,
        status: status ?? this.status,
      );
}
