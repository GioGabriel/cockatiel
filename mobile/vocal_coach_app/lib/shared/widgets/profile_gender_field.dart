import 'package:flutter/material.dart';
import '../models/user_models.dart';

class ProfileGenderField extends StatelessWidget {
  const ProfileGenderField(
      {super.key, required this.value, required this.onChanged});
  final ProfileGender? value;
  final ValueChanged<ProfileGender?> onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<ProfileGender>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Gender (optional)'),
          items: ProfileGender.values
              .map((gender) => DropdownMenuItem(
                  value: gender, child: Text(profileGenderLabel(gender))))
              .toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Text(
            switch (value) {
              ProfileGender.male =>
                'Common starting options: bass, baritone and tenor. Choose the range that feels comfortable.',
              ProfileGender.female =>
                'Common starting options: alto, mezzo-soprano and soprano. Choose the range that feels comfortable.',
              _ =>
                'All six voice ranges are available. Gender does not determine your singing range.',
            },
            style: Theme.of(context).textTheme.bodySmall),
      ]);
}
