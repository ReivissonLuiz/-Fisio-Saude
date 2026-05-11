import 'package:flutter/material.dart';

class GlobalScaleWidget extends StatelessWidget {
  final Widget child;
  final double scale;

  const GlobalScaleWidget({
    super.key,
    required this.child,
    this.scale = 0.85, // Reduz o tamanho de TUDO em 15%
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    // Calcula o tamanho "virtual" (maior) para que, ao reduzir, preencha a tela perfeitamente
    final virtualWidth = mediaQuery.size.width / scale;
    final virtualHeight = mediaQuery.size.height / scale;

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: MediaQuery(
        data: mediaQuery.copyWith(
          size: Size(virtualWidth, virtualHeight),
          padding: mediaQuery.padding / scale,
          viewInsets: mediaQuery.viewInsets / scale,
          viewPadding: mediaQuery.viewPadding / scale,
          devicePixelRatio: mediaQuery.devicePixelRatio * scale,
          textScaler: const TextScaler.linear(1.0), // Reseta textScaler pois tudo já foi reduzido
        ),
        child: SizedBox(
          width: virtualWidth,
          height: virtualHeight,
          child: child,
        ),
      ),
    );
  }
}
