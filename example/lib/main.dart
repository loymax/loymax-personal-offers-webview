import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loymax_personal_offers/loymax_personal_offers.dart';

import 'demo_config.dart';
import 'demo_gallery.dart';

void main() {
  runApp(const LoymaxDemoApp());
}

class LoymaxDemoApp extends StatelessWidget {
  const LoymaxDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loymax Personal Offers Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003874)),
        useMaterial3: true,
      ),
      home: const DemoHome(),
    );
  }
}

class DemoHome extends StatelessWidget {
  const DemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DEMO')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (BuildContext context) => const HomePage(),
                    ),
                  ),
              child: const Text('Home (carousel)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder:
                          (BuildContext context) => const DemoGalleryPage(),
                    ),
                  ),
              child: const Text('Builder gallery'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final LoymaxOffersController _offersController;

  @override
  void initState() {
    super.initState();
    _offersController = LoymaxOffersController();
  }

  @override
  void dispose() {
    _offersController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _offersController.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loymax Personal Offers'),
        actions: <Widget>[
          ListenableBuilder(
            listenable: _offersController,
            builder: (BuildContext context, Widget? _) {
              final bool isLoading =
                  _offersController.phase == LoymaxOffersPhase.loading;

              return IconButton(
                tooltip: 'Refresh',
                onPressed: isLoading ? null : _offersController.reload,
                icon:
                    isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh),
              );
            },
          ),
        ],
      ),
      body: ScrollConfiguration(
        behavior: const _NoScrollbarBehavior(),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            children: <Widget>[
              const _SectionTitle('Your offers'),
              LoymaxOffersCarousel(
                config: kLoymaxConfig,
                controller: _offersController,
                partner: kPartner,
                personUid: kPersonUid,
                backgroundColor: Theme.of(context).colorScheme.surface,
                loadingBuilder: (_) => const SizedBox(height: 280),
                errorBuilder: (_, _) => const SizedBox(height: 280),
                onEvent:
                    (LoymaxOfferEvent event) =>
                        _handleCarouselEvent(context, event),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton(
                  onPressed: () => _openFullScreen(context),
                  child: const Text('Open all offers'),
                ),
              ),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCarouselEvent(BuildContext context, LoymaxOfferEvent event) {
    switch (event) {
      case LoymaxViewAllTap():
      case LoymaxCardTap():
        _openFullScreen(context);
      case LoymaxActivateTap(offer: final LoymaxOffer offer):
        _showActivated(context, offer);
      case LoymaxNoContent():
        debugPrint('Loymax: no offers available for this user');
      case LoymaxOtherEvent(name: final String name):
        debugPrint('Unhandled Loymax event: $name');
    }
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PersonalOffersPage()),
    );
  }
}

class PersonalOffersPage extends StatefulWidget {
  const PersonalOffersPage({super.key});

  @override
  State<PersonalOffersPage> createState() => _PersonalOffersPageState();
}

class _PersonalOffersPageState extends State<PersonalOffersPage> {
  late final LoymaxOffersController _offersController;

  @override
  void initState() {
    super.initState();
    _offersController = LoymaxOffersController();
  }

  @override
  void dispose() {
    _offersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My offers'),
        actions: <Widget>[
          ListenableBuilder(
            listenable: _offersController,
            builder: (BuildContext context, Widget? _) {
              final bool isLoading =
                  _offersController.phase == LoymaxOffersPhase.loading;

              return IconButton(
                tooltip: 'Refresh',
                onPressed: isLoading ? null : _offersController.reload,
                icon:
                    isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh),
              );
            },
          ),
        ],
      ),
      body: LoymaxOffersView(
        config: kLoymaxConfig,
        controller: _offersController,
        partner: kPartner,
        personUid: kPersonUid,
        backgroundColor: Theme.of(context).colorScheme.surface,
        pullToRefreshEnabled: true,
        onEvent: (LoymaxOfferEvent event) {
          if (event is LoymaxActivateTap) {
            _showActivated(context, event.offer);
          }
        },
      ),
    );
  }
}

void _showActivated(BuildContext context, LoymaxOffer offer) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Activated: ${offer.name}')));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
