import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// This class controls the scroll behavior of the editor.
///
/// It must be provided in the widget tree above the [PageComponent].
///
/// You can use [offsetNotifier] to get the current scroll offset.
/// And, you can use [visibleRangeNotifier] to get the first level visible items.
///
/// If the shrinkWrap is true, the scrollController must not be null
///   and the editor should be wrapped in a SingleChildScrollView.
class EditorScrollController {
  EditorScrollController({
    required this.editorState,
    this.shrinkWrap = false,
    ScrollController? scrollController,
  }) {
    if (shrinkWrap) {
      void updateVisibleRange() {
        visibleRangeNotifier.value = (
          0,
          editorState.document.root.children.length - 1,
        );
      }

      updateVisibleRange();
      editorState.document.root.addListener(updateVisibleRange);

      shouldDisposeScrollController = scrollController == null;
      this.scrollController = scrollController ?? ScrollController();
      this.scrollController.addListener(
        () => offsetNotifier.value = this.scrollController.offset,
      );
    } else {
      shouldDisposeScrollController = scrollController == null;
      this.scrollController = scrollController ?? ScrollController();
      this.scrollController.addListener(
        () => offsetNotifier.value = this.scrollController.offset,
      );
      _listController.addListener(_listenVisibleRange);
    }
  }

  final EditorState editorState;
  final bool shrinkWrap;

  // provide the current scroll offset
  final ValueNotifier<double> offsetNotifier = ValueNotifier(0);

  // provide the first level visible items
  final ValueNotifier<(int, int)> visibleRangeNotifier =
      ValueNotifier((-1, -1));

  // standard ScrollController, used in both modes
  late final ScrollController scrollController;
  bool shouldDisposeScrollController = false;

  // ListController for super_sliver_list (non-shrinkWrap mode)
  ListController get listController {
    if (shrinkWrap) {
      throw UnsupportedError(
        'ListController is not supported when shrinkWrap is true',
      );
    }
    return _listController;
  }

  final ListController _listController = ListController();

  void dispose() {
    if (shouldDisposeScrollController) {
      scrollController.dispose();
    }

    if (!shrinkWrap) {
      _listController.removeListener(_listenVisibleRange);
      _listController.dispose();
    }

    offsetNotifier.dispose();
    visibleRangeNotifier.dispose();
  }

  Future<void> animateTo({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    if (scrollController.hasClients) {
      await scrollController.animateTo(
        offset.clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        ),
        duration: duration,
        curve: curve,
      );
    }
  }

  void jumpTo({
    required double offset,
  }) {
    if (shrinkWrap) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(
          offset.clamp(
            scrollController.position.minScrollExtent,
            scrollController.position.maxScrollExtent,
          ),
        );
      }
      return;
    }

    final index = offset.toInt();
    final (start, end) = visibleRangeNotifier.value;

    if (index < start || index > end) {
      _listController.jumpToItem(
        index: max(0, index),
        scrollController: scrollController,
        alignment: 0,
      );
    }
  }

  void jumpToTop() {
    if (shrinkWrap) {
      scrollController.jumpTo(0);
    } else {
      _listController.jumpToItem(
        index: 0,
        scrollController: scrollController,
        alignment: 0,
      );
    }
  }

  void jumpToBottom() {
    if (shrinkWrap) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    } else {
      _listController.jumpToItem(
        index: editorState.document.root.children.length - 1,
        scrollController: scrollController,
        alignment: 1.0,
      );
    }
  }

  void _listenVisibleRange() {
    final range = _listController.visibleRange;
    if (range == null) {
      visibleRangeNotifier.value = (-1, -1);
      return;
    }

    var (minIdx, maxIdx) = range;

    // filter the header and footer
    if (editorState.showHeader) {
      minIdx = max(0, minIdx - 1);
      maxIdx = max(0, maxIdx - 1);
    }

    if (editorState.showFooter &&
        maxIdx >= editorState.document.root.children.length) {
      maxIdx--;
    }

    visibleRangeNotifier.value = (minIdx, maxIdx);
  }
}

extension ValidIndexedValueNotifier on ValueNotifier<(int, int)> {
  /// Returns true if the value is valid.
  bool get isValid => value.$1 >= 0 && value.$2 >= 0 && value.$1 <= value.$2;
}
