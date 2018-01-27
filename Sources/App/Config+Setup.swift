import FluentProvider
import PostgreSQLProvider
import AuthProvider

extension Config {
    public func setup() throws {
        Node.fuzzy = [Row.self, JSON.self, Node.self]

        try setupProviders()
        try setupPreparations()
        setupMiddlewares()
    }

    private func setupProviders() throws {
        try addProvider(FluentProvider.Provider.self)
        try addProvider(PostgreSQLProvider.Provider.self)
        try addProvider(AuthProvider.Provider.self)
    }

    private func setupPreparations() throws {
        preparations.append(User.self)
        preparations.append(Token.self)
        preparations.append(Transaction.self)
        preparations.append(EndOfMonthSummary.self)
    }

    private func setupMiddlewares() {
        addConfigurable(middleware: GzipMiddleware(), name: "gzip")
    }
}
