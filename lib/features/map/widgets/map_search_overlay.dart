import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../search/search_view_model.dart';
import '../../../providers/providers.dart';
import 'search_input_bar.dart';
import 'search_results_list.dart';

/// Fullscreen search overlay for origin and destination station selection
class MapSearchOverlay extends ConsumerStatefulWidget {
  final bool focusDestination;

  const MapSearchOverlay({super.key, this.focusDestination = false});

  @override
  ConsumerState<MapSearchOverlay> createState() => _MapSearchOverlayState();
}

class _MapSearchOverlayState extends ConsumerState<MapSearchOverlay> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destFocusNode = FocusNode();

  bool _isSelectingOrigin = true;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _isSelectingOrigin = !widget.focusDestination;
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _originFocusNode.dispose();
    _destFocusNode.dispose();
    super.dispose();
  }

  void _initFields(SearchState state, String localeCode) {
    if (!_isFirstLoad) return;
    _isFirstLoad = false;

    _originController.text = state.origin != null
        ? state.origin!.displayName(isEnglish: localeCode == 'en')
        : '';
    _destController.text = state.destination != null
        ? state.destination!.displayName(isEnglish: localeCode == 'en')
        : '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      void requestInitialFocus() {
        if (!mounted) return;
        if (widget.focusDestination) {
          _startEditingDest(state);
        } else if (state.origin == null) {
          _startEditingOrigin(state);
        } else {
          _startEditingDest(state);
        }
      }

      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        if (route.animation!.isCompleted) {
          requestInitialFocus();
        } else {
          void listener(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              route.animation!.removeStatusListener(listener);
              requestInitialFocus();
            }
          }

          route.animation!.addStatusListener(listener);
        }
      } else {
        requestInitialFocus();
      }
    });
  }

  void _startEditingOrigin(SearchState state) {
    setState(() {
      _isSelectingOrigin = true;
    });
    _originController.text = state.origin != null
        ? state.origin!.displayName(isEnglish: ref.read(localeProvider) == 'en')
        : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_originFocusNode.canRequestFocus && mounted) {
        _originFocusNode.requestFocus();
      }
    });
    _originController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _originController.text.length,
    );
    ref.read(searchViewModelProvider.notifier).search(_originController.text);
  }

  void _startEditingDest(SearchState state) {
    setState(() {
      _isSelectingOrigin = false;
    });
    _destController.text = state.destination != null
        ? state.destination!.displayName(
            isEnglish: ref.read(localeProvider) == 'en',
          )
        : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_destFocusNode.canRequestFocus && mounted) {
        _destFocusNode.requestFocus();
      }
    });
    _destController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _destController.text.length,
    );
    ref.read(searchViewModelProvider.notifier).search(_destController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchViewModelProvider);
    final vm = ref.read(searchViewModelProvider.notifier);
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);

    _initFields(state, localeCode);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t.navigation.searchTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (state.origin != null || state.destination != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: t.search.clearAll,
              onPressed: () {
                vm.clear();
                _originController.clear();
                _destController.clear();
                _startEditingOrigin(ref.read(searchViewModelProvider));
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SearchInputBar(
              originController: _originController,
              destController: _destController,
              originFocusNode: _originFocusNode,
              destFocusNode: _destFocusNode,
              isSelectingOrigin: _isSelectingOrigin,
              originHint: t.search.originHint,
              destHint: t.search.destHint,
              onOriginTap: () => _startEditingOrigin(state),
              onDestTap: () => _startEditingDest(state),
              onOriginChanged: (query) => vm.search(query),
              onDestChanged: (query) => vm.search(query),
              onOriginClear: () {
                _originController.clear();
                vm.search('');
              },
              onDestClear: () {
                _destController.clear();
                vm.search('');
              },
              onSwap: state.origin != null || state.destination != null
                  ? () {
                      vm.swapStations();
                      final nextState = ref.read(searchViewModelProvider);
                      _originController.text = nextState.origin != null
                          ? nextState.origin!.displayName(
                              isEnglish: localeCode == 'en',
                            )
                          : '';
                      _destController.text = nextState.destination != null
                          ? nextState.destination!.displayName(
                              isEnglish: localeCode == 'en',
                            )
                          : '';
                      if (_isSelectingOrigin) {
                        _startEditingOrigin(nextState);
                      } else {
                        _startEditingDest(nextState);
                      }
                    }
                  : null,
            ),

            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Card(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Loading Indicator
            if (state.isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            Expanded(
              child: SearchResultsList(
                state: state,
                vm: vm,
                localeCode: localeCode,
                t: t,
                isSelectingOrigin: _isSelectingOrigin,
                onOriginSelected: (item) {
                  vm.setOrigin(item);
                  final nextState = ref.read(searchViewModelProvider);
                  _originController.text = item.displayName(
                    isEnglish: localeCode == 'en',
                  );
                  if (nextState.destination == null) {
                    _startEditingDest(nextState);
                  } else {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).pop(true);
                  }
                  vm.search('');
                },
                onDestSelected: (item) {
                  vm.setDestination(item);
                  final nextState = ref.read(searchViewModelProvider);
                  _destController.text = item.displayName(
                    isEnglish: localeCode == 'en',
                  );
                  if (nextState.origin == null) {
                    _startEditingOrigin(nextState);
                  } else {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).pop(true);
                  }
                  vm.search('');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
