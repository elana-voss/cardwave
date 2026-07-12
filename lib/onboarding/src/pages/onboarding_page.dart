import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/onboarding/src/controllers/onboarding_controller.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  OnboardingController? _controller;
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
    _controller!.init();
    _personaNameController.text = _controller!.personaName;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _personaNameController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_controller!.currentStep == _controller!.storageStepIndex) {
      _controller!.nextStep();
      return;
    }
    if (_controller!.currentStep == _controller!.setupStepIndex) {
      unawaited(_finishOnboarding());
    }
  }

  void _onStepCancel() {
    _controller!.previousStep();
  }

  void _snack(String message) {
    NavigationService().showSnackBar(message);
  }

  Future<void> _finishOnboarding() async {
    try {
      await _controller!.finishOnboarding();
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
      if (mounted) _snack(t.onboarding.finishFailedSnackbar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.onboarding.appBarTitle),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('onboarding-language'),
            icon: const Icon(Icons.language),
            tooltip: t.onboarding.languageTooltip,
            onPressed: () =>
                unawaited(NavigationService().showLanguageDialog()),
          ),
        ],
      ),
      body: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: ListenableBuilder(
          listenable: _controller!,
          builder: (context, _) {
            return _controller!.hasMultipleSteps
                ? _buildSteppedLayout()
                : _OnboardingSinglePageLayout(
                    setupBody: _buildSetupBody(),
                    canFinish: _controller!.canFinish,
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
      currentStep: _controller!.currentStep,
      onStepContinue: _onStepContinue,
      onStepCancel: _onStepCancel,
      controlsBuilder: (context, details) => _OnboardingStepperControls(
        details: details,
        currentStep: _controller!.currentStep,
        setupStepIndex: _controller!.setupStepIndex,
        canFinish: _controller!.canFinish,
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
      onChanged: _controller!.updatePersonaName,
    ),
    const SizedBox(height: 24),
    _OnboardingDisclaimerRow(
      accepted: _controller!.acceptedDisclaimer,
      onChanged: _controller!.updateAcceptedDisclaimer,
    ),
  ];

  Step _buildStorageStep() {
    final storageIndex = _controller!.storageStepIndex;
    final current = _controller!.currentStep;
    return Step(
      title: Text(t.onboarding.storageStep.title),
      subtitle: Text(t.onboarding.storageStep.subtitle),
      isActive: current >= storageIndex,
      state: current > storageIndex ? StepState.complete : StepState.editing,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.onboarding.storageStep.description),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.rocket_launch),
                label: Text(t.onboarding.storageStep.startFresh),
                onPressed: _controller!.selectDefaultPath,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: Text(t.onboarding.storageStep.haveCards),
                onPressed: _controller!.pickDirectory,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.onboarding.storageStep.importLaterHint,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _OnboardingStorageSelection(
            selectedPath: _controller!.selectedPath,
            useDefaultPath: _controller!.useDefaultPath,
          ),
        ],
      ),
    );
  }

  Step _buildSetupStep() {
    final setupIndex = _controller!.setupStepIndex;
    return Step(
      title: Text(t.onboarding.setupStep.title),
      isActive: _controller!.currentStep >= setupIndex,
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
        Text(
          t.onboarding.aiSection.heading,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(t.onboarding.aiSection.optionalHint),
        const SizedBox(height: 12),
        TextFieldAutotrim(
          key: const Key('onboarding-api-key'),
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: t.onboarding.aiSection.apiKeyLabel,
            border: const OutlineInputBorder(),
            hintText: t.onboarding.aiSection.apiKeyHint,
          ),
          obscureText: true,
          onChanged: _controller!.updateApiKey,
        ),
        const SizedBox(height: 8),
        _OnboardingAiStatus(
          isFetchingModels: _controller!.isFetchingModels,
          fetchError: _controller!.fetchError,
          hasAiConnected: _controller!.hasAiConnected,
          selectedProvider: _controller!.selectedProvider,
          apiKey: _controller!.apiKey,
        ),
        const SizedBox(height: 4),
        Text(
          t.onboarding.aiSection.supportedProviders,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) ...[
          const SizedBox(height: 8),
          _OnboardingLocalGgufRow(
            profile: _controller!.localGgufProfile,
            onPick: _controller!.pickLocalGguf,
          ),
        ],
        if (_controller!.selectedProvider == LLMProviderEnum.openrouter)
          SwitchTileZdr(
            value: _controller!.requireZdr,
            onChanged: _controller!.isFetchingModels
                ? null
                : _controller!.updateRequireZdr,
          ),
      ],
    );
  }
}

/// Subordinate affordance on the onboarding LLM step for users who want to
/// run an in-process local GGUF instead of (or in addition to) a cloud API.
/// Hidden on web and Android because the in-process provider is desktop-only.
class _OnboardingLocalGgufRow extends StatelessWidget {
  const _OnboardingLocalGgufRow({required this.profile, required this.onPick});
  final LlmProviderConfig? profile;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: p != null,
      title: Text(
        kHaveLocalGgufExpanderTitle,
        style: const TextStyle(fontSize: 13),
      ),
      children: [
        if (p != null)
          _LoadedRow(profile: p, onChange: onPick)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(kPickFileLabel),
              onPressed: onPick,
            ),
          ),
      ],
    );
  }
}

class _LoadedRow extends StatelessWidget {
  const _LoadedRow({required this.profile, required this.onChange});
  final LlmProviderConfig profile;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final firstModel = profile.models.firstOrNull;
    final modelName = firstModel?.name ?? t.onboarding.aiSection.unknownModel;
    final ctx = profile.contextSize;
    final kv = profile.kvCacheType;
    final ctxText = ctx == null
        ? t.onboarding.aiSection.ctxUnknown
        : t.onboarding.aiSection.ctxValue(ctx: ctx);
    final kvText = kv == null
        ? ''
        : t.onboarding.aiSection.kvSuffix(kv: kv.name);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle, color: Colors.green),
      title: Text(
        modelName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$ctxText$kvText'),
      trailing: TextButton(
        onPressed: onChange,
        child: Text(t.onboarding.aiSection.changeButton),
      ),
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
    final t = Translations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        if (kIsWeb) ...[
          Text(
            t.onboarding.webWarning,
            style: const TextStyle(color: Colors.orange, fontSize: 12),
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
            child: Text(t.onboarding.finishButton),
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
    final t = Translations.of(context);
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
            child: Text(
              isLastStep ? t.onboarding.finishButton : t.onboarding.nextButton,
            ),
          ),
          if (currentStep > 0)
            TextButton(
              onPressed: details.onStepCancel,
              child: Text(t.onboarding.backButton),
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
    final t = Translations.of(context);
    final successColor = Theme.of(context).colorScheme.primary;
    if (selectedPath != null) {
      return Text(
        t.onboarding.storageStep.selectedPath(path: selectedPath!),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: successColor,
        ),
      );
    }
    if (useDefaultPath) {
      return Text(
        t.onboarding.storageStep.selectedDefaultFolder,
        style: TextStyle(fontWeight: FontWeight.bold, color: successColor),
      );
    }
    return Text(
      t.onboarding.storageStep.noFolderSelected,
      style: const TextStyle(fontStyle: FontStyle.italic),
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
    final t = Translations.of(context);
    if (isFetchingModels) {
      return Row(
        spacing: 8,
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Text(
            t.onboarding.aiStatus.connecting,
            style: const TextStyle(fontSize: 12),
          ),
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
        t.onboarding.aiStatus.connected(
          provider: LlmProvider.of(selectedProvider!).label,
        ),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
        ),
      );
    }
    if (selectedProvider != null) {
      return Text(
        t.onboarding.aiStatus.detected(
          provider: LlmProvider.of(selectedProvider!).label,
        ),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    if (apiKey.isNotEmpty) {
      return Text(
        t.onboarding.aiStatus.unrecognizedKey,
        style: const TextStyle(color: Colors.orange, fontSize: 12),
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
    final t = Translations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.onboarding.personaSection.heading,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(t.onboarding.personaSection.hint),
        const SizedBox(height: 12),
        TextFieldAutotrim(
          controller: personaNameController,
          decoration: InputDecoration(
            labelText: t.onboarding.personaSection.nameLabel,
            border: const OutlineInputBorder(),
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
    final t = Translations.of(context);
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
              Text(t.onboarding.disclaimer.prefix),
              InkWell(
                onTap: () => launchUrl(Uri.parse(AppConstants.disclaimer)),
                child: Text(
                  t.onboarding.disclaimer.linkText,
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
