import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final VoidCallback onBack;
  const PrivacyPolicyScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Política de Privacidade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              GestureDetector(
                onTap: onBack,
                child: const Text('✕',
                    style: TextStyle(color: Colors.white54, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(child: _PolicyText()),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onBack,
            child: const Text(
              'Voltar',
              style: TextStyle(color: Colors.white54, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyText extends StatelessWidget {
  const _PolicyText();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Section(
            title: 'Última atualização: abril de 2026',
            body:
                'Este aplicativo ("Ballz") é desenvolvido de forma independente. '
                'Esta Política de Privacidade explica como coletamos, usamos e '
                'protegemos suas informações ao usar nosso aplicativo.',
          ),
          _Section(
            title: '1. Dados coletados',
            body:
                'Não coletamos diretamente nenhum dado pessoal identificável. '
                'No entanto, utilizamos serviços de terceiros que podem coletar '
                'informações para fins publicitários, incluindo:\n\n'
                '• Identificador de publicidade (Advertising ID)\n'
                '• Informações do dispositivo (modelo, sistema operacional)\n'
                '• Endereço IP\n'
                '• Dados de uso e interação com anúncios',
          ),
          _Section(
            title: '2. Publicidade (Unity Ads)',
            body:
                'Este aplicativo utiliza o Unity Ads (Unity Technologies) para '
                'exibir anúncios. O Unity Ads pode coletar e processar dados '
                'para personalizar anúncios conforme sua política de privacidade.\n\n'
                'Para mais informações sobre as práticas de privacidade do Unity Ads, '
                'acesse: unity.com/legal/privacy-policy',
          ),
          _Section(
            title: '3. Uso dos dados',
            body:
                'Os dados coletados pelos serviços de terceiros são utilizados '
                'exclusivamente para:\n\n'
                '• Exibição de anúncios relevantes\n'
                '• Medição de desempenho de anúncios\n'
                '• Prevenção de fraudes',
          ),
          _Section(
            title: '4. Seus direitos (LGPD)',
            body:
                'Em conformidade com a Lei Geral de Proteção de Dados (Lei nº '
                '13.709/2018), você tem direito a:\n\n'
                '• Saber quais dados são coletados\n'
                '• Solicitar a exclusão dos seus dados\n'
                '• Revogar o consentimento a qualquer momento\n\n'
                'Para redefinir seu Advertising ID ou desativar '
                'anúncios personalizados, acesse as configurações do seu dispositivo '
                'Android em: Configurações > Google > Anúncios.',
          ),
          _Section(
            title: '5. Retenção de dados',
            body:
                'Não armazenamos dados pessoais em nossos servidores. '
                'Os dados de progresso do jogo são armazenados apenas localmente '
                'no seu dispositivo.',
          ),
          _Section(
            title: '6. Menores de idade',
            body:
                'Este aplicativo não é direcionado a crianças menores de 13 anos. '
                'Não coletamos intencionalmente dados de menores de idade.',
          ),
          _Section(
            title: '7. Contato',
            body:
                'Se você tiver dúvidas sobre esta Política de Privacidade, '
                'entre em contato:\n\n'
                'E-mail: j.a.brito@live.com',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1D9E75),
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
