enum PaymentProviderType {
  card,
  cashOnDelivery,
  tabby,
  tamara,
}

class PaymentMethodOption {
  final PaymentProviderType provider;
  final String methodCode;

  const PaymentMethodOption({
    required this.provider,
    required this.methodCode,
  });

  bool get isBnpl =>
      provider == PaymentProviderType.tabby ||
      provider == PaymentProviderType.tamara;

  String providerCode() {
    switch (provider) {
      case PaymentProviderType.card:
        return 'card';
      case PaymentProviderType.cashOnDelivery:
        return 'cod';
      case PaymentProviderType.tabby:
        return 'tabby';
      case PaymentProviderType.tamara:
        return 'tamara';
    }
  }
}