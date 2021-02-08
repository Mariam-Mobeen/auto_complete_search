library auto_complete_search;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef Widget AutoCompleteOverlayItemBuilder<T>(
    BuildContext context, T suggestion);

typedef bool Filter<T>(T suggestion, String query);

typedef InputEventCallback<T>(T data);

typedef StringCallback(String data);

enum SuggestionsDirection { down, up }

class AutoCompleteSearchField<T> extends StatefulWidget {
  final List<T> suggestions;
  final Filter<T> itemFilter;
  final Comparator<T> itemSorter;
  final StringCallback textChanged, textSubmitted;
  final ValueSetter<bool> onFocusChanged;
  final InputEventCallback<T> itemSubmitted;
  final AutoCompleteOverlayItemBuilder<T> itemBuilder;
  final GlobalKey<AutoCompleteSearchFieldState<T>> key;
  final bool submitOnSuggestionTap, clearOnSubmit;
  final List<TextInputFormatter> inputFormatters;
  final int minLength;

  final InputDecoration decoration;
  final TextStyle style;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final TextEditingController controller;
  final FocusNode focusNode;
  final SuggestionsDirection suggestionsDirection;
  final num suggestionWidgetSize;

  AutoCompleteSearchField(
      {@required
          this.itemSubmitted, //Callback on item selected, this is the item selected of type <T>
      @required
          this.key, //GlobalKey used to enable addSuggestion etc
      @required
          this.suggestions, //Suggestions that will be displayed
      @required
          this.itemBuilder, //Callback to build each item, return a Widget
      @required
          this.itemSorter, //Callback to sort items in the form (a of type <T>, b of type <T>)
      @required
          this.itemFilter, //Callback to filter item: return true or false depending on input text
      this.inputFormatters,
      this.style,
      this.decoration: const InputDecoration(),
      this.textChanged, //Callback on input text changed, this is a string
      this.textSubmitted, //Callback on input text submitted, this is also a string
      this.onFocusChanged,
      this.keyboardType: TextInputType.text,
      this.suggestionsDirection: SuggestionsDirection
          .down, //What direction to show suggestions in? If your textfield is at the bottom of the page use SuggestionsDirection.up .
      this.suggestionWidgetSize:
          -1, //The amount of suggestions to show, larger values may result in them going off screen
      this.submitOnSuggestionTap:
          true, //Call textSubmitted on suggestion tap, itemSubmitted will be called no matter what
      this.clearOnSubmit: true, //Clear autoCompleteTextfield on submit
      this.textInputAction: TextInputAction.done,
      this.textCapitalization: TextCapitalization.sentences,
      this.minLength = 1,
      this.controller,
      this.focusNode})
      : super(key: key);

  void clear() => key.currentState.clear();

  void addSuggestion(T suggestion) =>
      key.currentState.addSuggestion(suggestion);

  void removeSuggestion(T suggestion) =>
      key.currentState.removeSuggestion(suggestion);

  void updateSuggestions(List<T> suggestions) =>
      key.currentState.updateSuggestions(suggestions);

  void triggerSubmitted() => key.currentState.triggerSubmitted();

  void updateDecoration(
          {InputDecoration decoration,
          List<TextInputFormatter> inputFormatters,
          TextCapitalization textCapitalization,
          TextStyle style,
          TextInputType keyboardType,
          TextInputAction textInputAction}) =>
      key.currentState.updateDecoration(decoration, inputFormatters,
          textCapitalization, style, keyboardType, textInputAction);

  TextField get textField => key.currentState.textField;

  @override
  State<StatefulWidget> createState() => new AutoCompleteSearchFieldState<T>(
      suggestions,
      textChanged,
      textSubmitted,
      onFocusChanged,
      itemSubmitted,
      itemBuilder,
      itemSorter,
      itemFilter,
      suggestionsDirection,
      suggestionWidgetSize,
      submitOnSuggestionTap,
      clearOnSubmit,
      minLength,
      inputFormatters,
      textCapitalization,
      decoration,
      style,
      keyboardType,
      textInputAction,
      controller,
      focusNode);
}

class AutoCompleteSearchFieldState<T> extends State<AutoCompleteSearchField> {
  final LayerLink _layerLink = LayerLink();

  TextField textField;
  List<T> suggestions;
  StringCallback textChanged, textSubmitted;
  ValueSetter<bool> onFocusChanged;
  InputEventCallback<T> itemSubmitted;
  AutoCompleteOverlayItemBuilder<T> itemBuilder;
  Comparator<T> itemSorter;
  OverlayEntry listSuggestionsEntry;
  List<T> filteredSuggestions;
  Filter<T> itemFilter;
  SuggestionsDirection suggestionsDirection;
  num suggestionWidgetHeight;
  int minLength;
  bool submitOnSuggestionTap, clearOnSubmit;
  TextEditingController controller;
  FocusNode focusNode;

  String currentText = "";

  InputDecoration decoration;
  List<TextInputFormatter> inputFormatters;
  TextCapitalization textCapitalization;
  TextStyle style;
  TextInputType keyboardType;
  TextInputAction textInputAction;

  AutoCompleteSearchFieldState(
      this.suggestions,
      this.textChanged,
      this.textSubmitted,
      this.onFocusChanged,
      this.itemSubmitted,
      this.itemBuilder,
      this.itemSorter,
      this.itemFilter,
      this.suggestionsDirection,
      this.suggestionWidgetHeight,
      this.submitOnSuggestionTap,
      this.clearOnSubmit,
      this.minLength,
      this.inputFormatters,
      this.textCapitalization,
      this.decoration,
      this.style,
      this.keyboardType,
      this.textInputAction,
      this.controller,
      this.focusNode) {
    if (suggestionsDirection == SuggestionsDirection.up &&
        suggestionWidgetHeight == -1) {
      throw "Suggestion widget size must be defined for non-standard suggestion direction!";
    }

    textField = new TextField(
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: decoration,
      style: style,
      keyboardType: keyboardType,
      focusNode: focusNode ?? new FocusNode(),
      controller: controller ?? new TextEditingController(),
      textInputAction: textInputAction,
      onChanged: (newText) {
        currentText = newText;
        updateOverlay(newText);

        if (textChanged != null) {
          textChanged(newText);
        }
      },
      onTap: () {
        updateOverlay(currentText);
      },
      onSubmitted: (submittedText) =>
          triggerSubmitted(submittedText: submittedText),
    );

    if (this.controller != null && this.controller.text != null) {
      currentText = this.controller.text;
    }

    textField.focusNode.addListener(() {
      if (onFocusChanged != null) {
        onFocusChanged(textField.focusNode.hasFocus);
      }

      if (!textField.focusNode.hasFocus) {
        filteredSuggestions = [];
        updateOverlay();
      } else if (!(currentText == "" || currentText == null)) {
        updateOverlay(currentText);
      }
    });
  }

  void updateDecoration(
      InputDecoration decoration,
      List<TextInputFormatter> inputFormatters,
      TextCapitalization textCapitalization,
      TextStyle style,
      TextInputType keyboardType,
      TextInputAction textInputAction) {
    if (decoration != null) {
      this.decoration = decoration;
    }

    if (inputFormatters != null) {
      this.inputFormatters = inputFormatters;
    }

    if (textCapitalization != null) {
      this.textCapitalization = textCapitalization;
    }

    if (style != null) {
      this.style = style;
    }

    if (keyboardType != null) {
      this.keyboardType = keyboardType;
    }

    if (textInputAction != null) {
      this.textInputAction = textInputAction;
    }

    setState(() {
      textField = new TextField(
        inputFormatters: this.inputFormatters,
        textCapitalization: this.textCapitalization,
        decoration: this.decoration,
        style: this.style,
        keyboardType: this.keyboardType,
        focusNode: focusNode ?? new FocusNode(),
        controller: controller ?? new TextEditingController(),
        textInputAction: this.textInputAction,
        onChanged: (newText) {
          currentText = newText;
          updateOverlay(newText);

          if (textChanged != null) {
            textChanged(newText);
          }
        },
        onTap: () {
          updateOverlay(currentText);
        },
        onSubmitted: (submittedText) =>
            triggerSubmitted(submittedText: submittedText),
      );
    });
  }

  void triggerSubmitted({submittedText}) {
    submittedText == null
        ? textSubmitted(currentText)
        : textSubmitted(submittedText);

    if (clearOnSubmit) {
      clear();
    }
  }

  void clear() {
    textField.controller.clear();
    currentText = "";
    updateOverlay();
  }

  void addSuggestion(T suggestion) {
    suggestions.add(suggestion);
    updateOverlay(currentText);
  }

  void removeSuggestion(T suggestion) {
    suggestions.contains(suggestion)
        ? suggestions.remove(suggestion)
        : throw "List does not contain suggestion and therefore cannot be removed";
    updateOverlay(currentText);
  }

  void updateSuggestions(List<T> suggestions) {
    this.suggestions = suggestions;
    updateOverlay(currentText);
  }

  void updateOverlay([String query]) {
    if (listSuggestionsEntry == null) {
      final Size textFieldSize = (context.findRenderObject() as RenderBox).size;
      final width = textFieldSize.width;
      final height = textFieldSize.height;

      listSuggestionsEntry = new OverlayEntry(builder: (context) {
        List<Widget> filteredSuggestionsWidgets =
            filteredSuggestions.map((suggestion) {
          return new Row(children: [
            new Expanded(
                child: new InkWell(
                    child: suggestionsDirection == SuggestionsDirection.up
                        ? SizedBox(
                            child: itemBuilder(context, suggestion),
                            height: suggestionWidgetHeight,
                          )
                        : itemBuilder(context, suggestion),
                    onTap: () {
                      setState(() {
                        if (submitOnSuggestionTap) {
                          String newText = suggestion.toString();
                          textField.controller.text = newText;
                          textField.focusNode.unfocus();
                          itemSubmitted(suggestion);
                          if (clearOnSubmit) {
                            clear();
                          }
                        } else {
                          String newText = suggestion.toString();
                          textField.controller.text = newText;
                          textChanged(newText);
                        }
                      });
                    }))
          ]);
        }).toList();

        final suggestionsOffsetHeight =
            suggestionsDirection == SuggestionsDirection.down
                ? height
                : -(height -
                    35.0 +
                    suggestionWidgetHeight *
                        (filteredSuggestionsWidgets.length < 5
                            ? filteredSuggestionsWidgets.length
                            : 5));

        return new Positioned(
            width: width,
            child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0.0, suggestionsOffsetHeight),
                child: new SizedBox(
                    width: width,
                    child: new Card(
                        child: new ConstrainedBox(
                            constraints: new BoxConstraints(
                              minHeight: 0,
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.3,
                            ),
                            child: new SingleChildScrollView(
                                child: new Column(
                              children: filteredSuggestionsWidgets,
                            )))))));
      });
      Overlay.of(context).insert(listSuggestionsEntry);
    }

    filteredSuggestions =
        getSuggestions(suggestions, itemSorter, itemFilter, query);

    listSuggestionsEntry.markNeedsBuild();
  }

  List<T> getSuggestions(List<T> suggestions, Comparator<T> sorter,
      Filter<T> filter, String query) {
    if (null == query || query.length < minLength) {
      return [];
    }

    suggestions = suggestions.where((item) => filter(item, query)).toList();
    suggestions.sort(sorter);

    return suggestions;
  }

  @override
  void dispose() {
    // if we created our own focus node and controller, dispose of them
    // otherwise, let the caller dispose of their own instances
    if (focusNode == null) {
      textField.focusNode.dispose();
    }
    if (controller == null) {
      textField.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _layerLink, child: textField);
  }
}

class SimpleAutoCompleteTextField extends AutoCompleteSearchField<String> {
  final StringCallback textChanged, textSubmitted;
  final int minLength;
  final ValueSetter<bool> onFocusChanged;
  final TextEditingController controller;
  final FocusNode focusNode;

  SimpleAutoCompleteTextField(
      {TextStyle style,
      InputDecoration decoration: const InputDecoration(),
      this.onFocusChanged,
      this.textChanged,
      this.textSubmitted,
      this.minLength = 1,
      this.controller,
      this.focusNode,
      TextInputType keyboardType: TextInputType.text,
      @required GlobalKey<AutoCompleteSearchFieldState<String>> key,
      @required List<String> suggestions,
      bool submitOnSuggestionTap: true,
      bool clearOnSubmit: true,
      TextInputAction textInputAction: TextInputAction.done,
      TextCapitalization textCapitalization: TextCapitalization.sentences})
      : super(
            style: style,
            decoration: decoration,
            textChanged: textChanged,
            textSubmitted: textSubmitted,
            itemSubmitted: textSubmitted,
            keyboardType: keyboardType,
            key: key,
            suggestions: suggestions,
            itemBuilder: null,
            itemSorter: null,
            itemFilter: null,
            submitOnSuggestionTap: submitOnSuggestionTap,
            clearOnSubmit: clearOnSubmit,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization);

  @override
  State<StatefulWidget> createState() =>
      new AutoCompleteSearchFieldState<String>(suggestions, textChanged,
          textSubmitted, onFocusChanged, itemSubmitted, (context, item) {
        return new Padding(padding: EdgeInsets.all(8.0), child: new Text(item));
      }, (a, b) {
        return a.compareTo(b);
      }, (item, query) {
        return item.toLowerCase().startsWith(query.toLowerCase());
      },
          SuggestionsDirection.down,
          -1, //Suggestions go in default direction so size doesnt need to be specified.
          submitOnSuggestionTap,
          clearOnSubmit,
          minLength,
          [],
          textCapitalization,
          decoration,
          style,
          keyboardType,
          textInputAction,
          controller,
          focusNode);
}
