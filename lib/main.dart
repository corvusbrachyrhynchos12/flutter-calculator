import 'package:flutter/material.dart';
import 'package:expressions/expressions.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Andrew's Calculator",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // The expression currently being built, e.g. "2+3*4"
  String _expression = '';
  // The full accumulator line shown once "=" is pressed, e.g. "2+3*4 = 14"
  String _accumulator = '';
  bool _hasError = false;

  static const _operators = ['+', '-', '*', '/', '%'];

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _clear();
      } else if (value == '⌫') {
        _backspace();
      } else if (value == '=') {
        _evaluate();
      } else if (value == 'x²') {
        _square();
      } else if (_operators.contains(value)) {
        _appendOperator(value);
      } else {
        _appendInput(value);
      }
    });
  }

  void _clear() {
    _expression = '';
    _accumulator = '';
    _hasError = false;
  }

  void _backspace() {
    if (_hasError) {
      _clear();
      return;
    }
    if (_expression.isNotEmpty) {
      _expression = _expression.substring(0, _expression.length - 1);
    }
    _accumulator = '';
  }

  void _appendInput(String value) {
    // Starting a new calculation after a result was shown.
    if (_hasError) {
      _clear();
    } else if (_accumulator.isNotEmpty) {
      _expression = '';
      _accumulator = '';
    }

    if (value == '.') {
      // Prevent multiple decimal points in the current number segment.
      final lastSegment = _lastNumberSegment(_expression);
      if (lastSegment.contains('.')) return;
      if (lastSegment.isEmpty) {
        _expression += '0';
      }
    }

    _expression += value;
    _accumulator = '';
  }

  void _appendOperator(String op) {
    if (_hasError) {
      _clear();
      return;
    }
    if (_accumulator.isNotEmpty) {
      // Chain from the previous result.
      _expression = _stripAccumulatorResult(_accumulator);
      _accumulator = '';
    }
    if (_expression.isEmpty) {
      // Allow a leading minus sign for negative numbers.
      if (op == '-') {
        _expression += op;
      }
      return;
    }
    final lastChar = _expression[_expression.length - 1];
    if (_operators.contains(lastChar)) {
      // Replace the trailing operator instead of stacking another one.
      _expression = _expression.substring(0, _expression.length - 1) + op;
    } else {
      _expression += op;
    }
  }

  String _lastNumberSegment(String expr) {
    final match = RegExp(r'[0-9.]*$').firstMatch(expr);
    return match?.group(0) ?? '';
  }

  String _stripAccumulatorResult(String accumulator) {
    final idx = accumulator.indexOf(' = ');
    return idx == -1 ? accumulator : accumulator.substring(0, idx);
  }

  /// Adds spaces around binary operators for a readable display,
  /// e.g. "2+3*4" -> "2 + 3 * 4". Leaves a leading unary minus untouched.
  String _formatForDisplay(String expr) {
    final buffer = StringBuffer();
    for (var i = 0; i < expr.length; i++) {
      final c = expr[i];
      if (_operators.contains(c) && i != 0) {
        buffer.write(' $c ');
      } else {
        buffer.write(c);
      }
    }
    return buffer.toString();
  }

  /// Squares the current expression (or the last result) and evaluates it,
  /// e.g. "2+3" -> "(2+3)*(2+3) = 25".
  void _square() {
    if (_hasError || _expression.isEmpty) return;

    final lastChar = _expression[_expression.length - 1];
    if (_operators.contains(lastChar)) return;

    // Wrap anything that isn't a plain positive number so the
    // multiplication keeps the right precedence.
    final operand = RegExp(r'^[0-9.]+$').hasMatch(_expression)
        ? _expression
        : '($_expression)';
    _expression = '$operand*$operand';
    _accumulator = '';
    _evaluate();
  }

  void _evaluate() {
    if (_expression.isEmpty) return;

    final trimmed = _expression.trimRight();
    final lastChar = trimmed.isNotEmpty ? trimmed[trimmed.length - 1] : '';
    if (_operators.contains(lastChar) || trimmed.isEmpty) {
      _accumulator = '$_expression = Error';
      _hasError = true;
      return;
    }

    try {
      final expression = Expression.parse(_expression);
      const evaluator = ExpressionEvaluator();
      final evalResult = evaluator.eval(expression, {});

      if (evalResult == null) {
        throw const FormatException('Invalid expression');
      }
      if (evalResult is num && evalResult.isInfinite) {
        throw const FormatException('Division by zero');
      }
      if (evalResult is num && evalResult.isNaN) {
        throw const FormatException('Invalid calculation');
      }

      final formatted = _formatResult(evalResult);
      _accumulator = '$_expression = $formatted';
      _expression = formatted;
      _hasError = false;
    } catch (e) {
      _accumulator = '$_expression = Error';
      _hasError = true;
    }
  }

  String _formatResult(dynamic result) {
    if (result is num) {
      if (result == result.roundToDouble() && result.abs() < 1e15) {
        return result.toStringAsFixed(0);
      }
      String s = result.toString();
      if (s.length > 12) {
        s = result.toStringAsPrecision(10);
        s = s.contains('.')
            ? s
                  .replaceFirst(RegExp(r'0+$'), '')
                  .replaceFirst(RegExp(r'\.$'), '')
            : s;
      }
      return s;
    }
    return result.toString();
  }

  Widget _buildButton(String text, Color color, {double flex = 1}) {
    return Expanded(
      flex: flex.round(),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          onPressed: () => _onButtonPressed(text),
          child: Text(
            text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayExpression = _formatForDisplay(
      _accumulator.isNotEmpty
          ? _stripAccumulatorResult(_accumulator)
          : _expression,
    );
    final displayResult = _accumulator.isNotEmpty
        ? _accumulator.substring(_accumulator.indexOf(' = ') + 3)
        : '';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Andrew's Calculator",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                alignment: Alignment.bottomRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        displayExpression.isEmpty ? '0' : displayExpression,
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayResult,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _hasError ? Colors.red : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _buildButton('C', Colors.red.shade400, flex: 1),
                        _buildButton('⌫', Colors.orange.shade400),
                        _buildButton('x²', Colors.blue.shade800),
                        _buildButton('/', Colors.blue.shade800),
                      ],
                    ),
                    Row(
                      children: [
                        _buildButton('7', Colors.blueGrey.shade600),
                        _buildButton('8', Colors.blueGrey.shade600),
                        _buildButton('9', Colors.blueGrey.shade600),
                        _buildButton('*', Colors.blue.shade800),
                      ],
                    ),
                    Row(
                      children: [
                        _buildButton('4', Colors.blueGrey.shade600),
                        _buildButton('5', Colors.blueGrey.shade600),
                        _buildButton('6', Colors.blueGrey.shade600),
                        _buildButton('-', Colors.blue.shade800),
                      ],
                    ),
                    Row(
                      children: [
                        _buildButton('1', Colors.blueGrey.shade600),
                        _buildButton('2', Colors.blueGrey.shade600),
                        _buildButton('3', Colors.blueGrey.shade600),
                        _buildButton('+', Colors.blue.shade800),
                      ],
                    ),
                    Row(
                      children: [
                        _buildButton('0', Colors.blueGrey.shade600),
                        _buildButton('.', Colors.blueGrey.shade600),
                        _buildButton('=', Colors.black87),
                        _buildButton('%', Colors.blue.shade800),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
