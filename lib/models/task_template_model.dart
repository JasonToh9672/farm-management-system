class TaskTemplateModel {
  String id;
  String title;
  String description;
  String category;
  String cropType;
  String priority;

  TaskTemplateModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.cropType,
    required this.priority,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'cropType': cropType,
        'priority': priority,
      };

  factory TaskTemplateModel.fromMap(Map<String, dynamic> map) =>
      TaskTemplateModel(
        id: map['id'],
        title: map['title'],
        description: map['description'],
        category: map['category'],
        cropType: map['cropType'],
        priority: map['priority'],
      );
}
