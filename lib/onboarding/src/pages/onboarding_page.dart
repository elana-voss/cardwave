import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/onboarding/src/controllers/onboarding_controller.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final OnboardingController _controller;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _personaNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = OnboardingController(
      settingsService: context.read<SettingsService>(),
      pureHelpers: context.read<LlmPureHelpers>(),
      llmManagementService: context.read<LlmManagementService>(),
    );
    _controller.init();
    _personaNameController.text = _controller.personaName;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _personaNameController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_controller.currentStep == _controller.storageStepIndex) {
      _controller.nextStep();
      return;
    }
    if (_controller.currentStep == _controller.setupStepIndex) {
      unawaited(_finishOnboarding());
    }
  }

  void _onStepCancel() {
    _controller.previousStep();
  }

  void _snack(String message) {
    NavigationService().showSnackBar(message);
  }

  Future<void> _finishOnboarding() async {
    try {
      await _controller.finishOnboarding();
      if (mounted) {
        await Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on Exception catch (e, stackTrace) {
      LoggingService().error(
        '[Onboarding] Failed to finish setup',
        e,
        stackTrace,
      );
      if (mounted) _snack('Setup failed. See logs for details.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Setup'),
        centerTitle: true,
      ),
      body: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return _controller.hasMultipleSteps
                ? _buildSteppedLayout()
                : _OnboardingSinglePageLayout(
                    setupBody: _buildSetupBody(),
                    canFinish: _controller.canFinish,
                    onFinish: _onStepContinue,
                  );
          },
        ),
      ),
    );
  }

  // The Stepper scaffold itself — its `steps:` are State-built Step
  // objects that read the controller; a widget class would just re-thread
  // all of it for no rebuild-boundary gain.
  // ignore: qcheck/avoid_returning_widgets
  Widget _buildSteppedLayout() {
    return Stepper(
      currentStep: _controller.currentStep,
      onStepContinue: _onStepContinue,
      onStepCancel: _onStepCancel,
      controlsBuilder: (context, details) => _OnboardingStepperControls(
        details: details,
        currentStep: _controller.currentStep,
        setupStepIndex: _controller.setupStepIndex,
        canFinish: _controller.canFinish,
      ),
      steps: [_buildStorageStep(), _buildSetupStep()],
    );
  }

  /// AI section + persona section + disclaimer row, with the same
  /// 24-px gaps between them. Shared by the single-page mobile layout
  /// and the Stepper's setup step so the two stay visually identical.
  List<Widget> _buildSetupBody() => [
    _buildAiSection(),
    const SizedBox(height: 24),
    _OnboardingPersonaSection(
      personaNameController: _personaNameController,
      onChanged: _controller.updatePersonaName,
    ),
    const SizedBox(height: 24),
    _OnboardingDisclaimerRow(
      accepted: _controller.acceptedDisclaimer,
      onChanged: _controller.updateAcceptedDisclaimer,
    ),
  ];

  Step _buildStorageStep() {
    final storageIndex = _controller.storageStepIndex;
    final current = _controller.currentStep;
    return Step(
      title: const Text('Character Storage'),
      subtitle: const Text('Where should we save your character cards?'),
      isActive: current >= storageIndex,
      state: current > storageIndex ? StepState.complete : StepState.editing,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved in the app folder by default. Point to an existing PNG folder to import.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Start fresh'),
                onPressed: _controller.selectDefaultPath,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('I already have cards'),
                onPressed: _controller.pickDirectory,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Import PNGs later via File → Import.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _OnboardingStorageSelection(
            selectedPath: _controller.selectedPath,
            useDefaultPath: _controller.useDefaultPath,
          ),
        ],
      ),
    );
  }

  Step _buildSetupStep() {
    final setupIndex = _controller.setupStepIndex;
    return Step(
      title: const Text('AI & Persona'),
      isActive: _controller.currentStep >= setupIndex,
      state: StepState.editing,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildSetupBody(),
      ),
    );
  }

  // Reads 6+ controller fields and uses the State-owned _apiKeyController;
  // a widget would re-thread all of it. Its inner status line IS extracted
  // (_OnboardingAiStatus below).
  // ignore: qcheck/avoid_returning_widgets
  Widget _buildAiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI Connection', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Optional — skip and add a key later in Settings (local providers can be added there too).',
        ),
        const SizedBox(height: 12),
        TextFieldAutotrim(
          key: const Key('onboarding-api-key'),
          controller: _apiKeyController,
          decoration: const InputDecoration(
            labelText: 'API Key',
            border: OutlineInputBorder(),
            hintText: 'Paste your key (or skip for now)',
          ),
          obscureText: true,
          onChanged: _controller.updateApiKey,
        ),
        const SizedBox(height: 8),
        _OnboardingAiStatus(
          isFetchingModels: _controller.isFetchingModels,
          fetchError: _controller.fetchError,
          hasAiConnected: _controller.hasAiConnected,
          selectedProvider: _controller.selectedProvider,
          apiKey: _controller.apiKey,
        ),
        const SizedBox(height: 4),
        const Text(
          'Supports OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT. More in Settings.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        if (_controller.selectedProvider == LLMProviderEnum.openrouter)
          SwitchTileZdr(
            value: _controller.requireZdr,
            onChanged: _controller.isFetchingModels
                ? null
                : _controller.updateRequireZdr,
          ),
      ],
    );
  }
}

/// Single-page (no-Stepper) onboarding layout — the setup body followed
/// by the Finish button. A ListView (not Column) so the form scrolls
/// when the soft keyboard pushes Finish below the fold on short screens.
class _OnboardingSinglePageLayout extends StatelessWidget {
  const _OnboardingSinglePageLayout({
    required this.setupBody,
    required this.canFinish,
    required this.onFinish,
  });
  final List<Widget> setupBody;
  final bool canFinish;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        if (kIsWeb) ...[
          const Text(
            'Experimental web build — browser storage may reset between updates. '
            'Use desktop or Android for persistent data.',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ],
        ...setupBody,
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('onboarding-finish'),
            onPressed: canFinish ? onFinish : null,
            child: const Text('Finish Setup'),
          ),
        ),
      ],
    );
  }
}

/// The Stepper's per-step controls — a "Next"/"Finish Setup" button plus
/// a "Back" button once past the first step. Built via `controlsBuilder`,
/// so it takes the framework's [ControlsDetails].
class _OnboardingStepperControls extends StatelessWidget {
  const _OnboardingStepperControls({
    required this.details,
    required this.currentStep,
    required this.setupStepIndex,
    required this.canFinish,
  });
  final ControlsDetails details;
  final int currentStep;
  final int setupStepIndex;
  final bool canFinish;

  @override
  Widget build(BuildContext context) {
    final isLastStep = currentStep == setupStepIndex;
    final blockContinue = isLastStep && !canFinish;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: OverflowBar(
        alignment: MainAxisAlignment.start,
        spacing: 8,
        overflowSpacing: 8,
        children: [
          FilledButton(
            key: Key(isLastStep ? 'onboarding-finish' : 'onboarding-next'),
            onPressed: blockContinue ? null : details.onStepContinue,
            child: Text(isLastStep ? 'Finish Setup' : 'Next'),
          ),
          if (currentStep > 0)
            TextButton(
              onPressed: details.onStepCancel,
              child: const Text('Back'),
            ),
        ],
      ),
    );
  }
}

/// Confirmation line under the storage-step buttons — shows the picked
/// folder, "Default app folder", or "No folder selected yet."
class _OnboardingStorageSelection extends StatelessWidget {
  const _OnboardingStorageSelection({
    required this.selectedPath,
    required this.useDefaultPath,
  });
  final String? selectedPath;
  final bool useDefaultPath;

  @override
  Widget build(BuildContext context) {
    final successColor = Theme.of(context).colorScheme.primary;
    if (selectedPath != null) {
      return Text(
        'Selected: $selectedPath',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: successColor,
        ),
      );
    }
    if (useDefaultPath) {
      return Text(
        'Selected: Default app folder',
        style: TextStyle(fontWeight: FontWeight.bold, color: successColor),
      );
    }
    return const Text(
      'No folder selected yet.',
      style: TextStyle(fontStyle: FontStyle.italic),
    );
  }
}

/// The AI-connection status line — spinner / error / detected-provider /
/// connected, depending on the controller's fetch state.
class _OnboardingAiStatus extends StatelessWidget {
  const _OnboardingAiStatus({
    required this.isFetchingModels,
    required this.fetchError,
    required this.hasAiConnected,
    required this.selectedProvider,
    required this.apiKey,
  });
  final bool isFetchingModels;
  final String? fetchError;
  final bool hasAiConnected;
  final LLMProviderEnum? selectedProvider;
  final String apiKey;

  @override
  Widget build(BuildContext context) {
    if (isFetchingModels) {
      return const Row(
        spacing: 8,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Text('Connecting…', style: TextStyle(fontSize: 12)),
        ],
      );
    }
    if (fetchError != null) {
      return Text(
        fetchError!,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      );
    }
    if (hasAiConnected) {
      return Text(
        'Connected to ${LlmProvider.of(selectedProvider!).label}. '
        'Default chat model selected.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
        ),
      );
    }
    if (selectedProvider != null) {
      return Text(
        'Detected: ${LlmProvider.of(selectedProvider!).label}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    if (apiKey.isNotEmpty) {
      return const Text(
        'Unrecognized key format.',
        style: TextStyle(color: Colors.orange, fontSize: 12),
      );
    }
    return const SizedBox(height: 14);
  }
}

/// The "Your Persona" name field section.
class _OnboardingPersonaSection extends StatelessWidget {
  const _OnboardingPersonaSection({
    required this.personaNameController,
    required this.onChanged,
  });
  final TextEditingController personaNameController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Persona', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Your name in chats. More persona details in Settings.'),
        const SizedBox(height: 12),
        TextFieldAutotrim(
          controller: personaNameController,
          decoration: const InputDecoration(
            labelText: 'Your name',
            border: OutlineInputBorder(),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The disclaimer checkbox + "I have read and agree to the Disclaimer"
/// link row.
class _OnboardingDisclaimerRow extends StatelessWidget {
  const _OnboardingDisclaimerRow({
    required this.accepted,
    required this.onChanged,
  });
  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final linkColor = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Checkbox(
          key: const Key('onboarding-disclaimer'),
          value: accepted,
          onChanged: (val) => onChanged(val ?? false),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('I have read and agree to the '),
              InkWell(
                onTap: () => launchUrl(Uri.parse(AppConstants.disclaimer)),
                child: Text(
                  'Disclaimer',
                  style: TextStyle(
                    color: linkColor,
                    decoration: TextDecoration.underline,
                    decorationColor: linkColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
