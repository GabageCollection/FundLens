import 'package:fundlens_core/fundlens_core.dart';

/// Distinct load states of the portfolio stream consumed by pages.
///
/// Loading, empty, data and degraded are separate types so pages render an
/// explicit state instead of guessing from `null` values.
sealed class PortfolioState {
  const PortfolioState();
}

/// The holdings stream has not emitted its first value yet.
final class PortfolioLoading extends PortfolioState {
  const PortfolioLoading();
}

/// The stream emitted an empty holding list.
final class PortfolioEmpty extends PortfolioState {
  const PortfolioEmpty();
}

/// The stream emitted at least one holding.
final class PortfolioReady extends PortfolioState {
  const PortfolioReady(this.holdings);

  final List<Holding> holdings;
}

/// The stream failed; the app keeps running with degraded data.
final class PortfolioDegraded extends PortfolioState {
  const PortfolioDegraded(this.error);

  final Object error;
}
