import '../model/asset.dart';
import 'price_provider.dart';

/// Holds the registered [PriceProvider]s and picks the first that supports a
/// given asset. Adding a provider needs no change to existing ones.
class ProviderRegistry {
  final List<PriceProvider> _providers;

  ProviderRegistry([List<PriceProvider>? providers])
      : _providers = [...?providers];

  void register(PriceProvider provider) => _providers.add(provider);

  PriceProvider? providerFor(Asset asset) {
    for (final provider in _providers) {
      if (provider.supports(asset)) return provider;
    }
    return null;
  }

  Iterable<PriceProvider> get providers => List.unmodifiable(_providers);
}
