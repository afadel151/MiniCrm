# MiniCRM

MiniCRM is a multi-tenant customer relationship management app. The repository contains an ASP.NET Core API and a Nuxt web client, backed by SQL Server. Development is currently focused on authentication and session handling.

## Project Status

Authentication is the active development phase. The API currently has endpoints for user registration, login, access to the current user's profile, refresh-token rotation, and logout. The web client has login and registration pages and server routes that call the API and keep authentication data in a server-side session.

Google authentication services and business registration logic are present in the code, but their complete user flows are not yet exposed through the API. Business registration also still needs to create its business/tenant record. Treat the rest of the CRM domain as in development; the presence of database entities does not mean those features are complete.

## Technology

- .NET 10 and ASP.NET Core Web API
- ASP.NET Core Identity and JWT bearer authentication
- Entity Framework Core with SQL Server
- Nuxt 4, Vue 3, and TypeScript
- Bun for the web client package scripts and lockfile
- Docker Compose for local SQL Server

## Repository Layout

| Path | Purpose |
| --- | --- |
| `src/Api` | ASP.NET Core API, controllers, OpenAPI/Swagger, and app configuration |
| `src/Application` | Authentication, token, Google sign-in, and audit services; request/response DTOs |
| `src/Core` | Shared options, constants, enums, and exceptions |
| `src/Infrastructure` | Identity models, EF Core context, SQL Server mappings, and migrations |
| `src/Web` | Nuxt web client, pages, and server-side API/session routes |
| `tests/MiniCrm.Tests` | .NET tests for architecture, data access, current-user behavior, and local time |
| `docker-compose.yml` | Local SQL Server service |

## Prerequisites

- .NET 10 SDK (the repository pins SDK `10.0.112`, with feature-band roll-forward enabled)
- Docker with the Compose plugin
- Bun

## Run Locally

### 1. Start SQL Server

From the repository root:

```sh
docker compose up -d sqlserver
```

The Compose file publishes SQL Server on port `1433`. Configure a strong local SA password before using this setup beyond a private development machine, and make the API connection string match it.

### 2. Configure the API

The API requires `ConnectionStrings:Default` and a JWT signing key of at least 32 characters. Store local values with .NET User Secrets rather than committing secrets to `appsettings.json`:

```sh
dotnet user-secrets set --project src/Api "ConnectionStrings:Default" "Server=localhost,1433;Database=MiniCrm;User Id=sa;Password=<your-local-password>;TrustServerCertificate=True"
dotnet user-secrets set --project src/Api "Jwt:Key" "<a-random-secret-at-least-32-characters-long>"
```

The JWT issuer and audience have development defaults in `src/Api/appsettings.json`. Optional Google sign-in credentials can also be supplied as User Secrets if and when that flow is enabled. Do not put production credentials in source control.

### 3. Apply database migrations

```sh
dotnet ef database update --project src/Infrastructure --startup-project src/Api
```

If the `dotnet ef` command is unavailable, install the configured tool from the repository root:

```sh
dotnet tool restore
```

### 4. Run the API

```sh
dotnet run --project src/Api
```

The development launch profile listens at `https://localhost:7056` and `http://localhost:5195`. Swagger is enabled in the Development environment.

### 5. Run the web client

In another terminal:

```sh
cd src/Web
bun install
bun run dev
```

Nuxt's development server prints its local URL when it starts. By default, the web server calls the API at `https://localhost:5001`; set `API_BASE_URL` to the API URL above when running locally, for example:

```sh
API_BASE_URL=https://localhost:7056 bun run dev
```

The API CORS allow-list should include the origin Nuxt prints if it differs from the configured defaults.

## Authentication API

The API base route is `/api/auth`:

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/register` | Register a client account |
| `POST` | `/login` | Validate credentials and issue access and refresh tokens |
| `GET` | `/me` | Return the authenticated user's profile and roles |
| `POST` | `/refresh` | Rotate a refresh token and issue a new access token |
| `POST` | `/logout` | Revoke the refresh-token session |

The Nuxt server exposes matching login, registration, and logout routes to the browser and stores authentication data in its server-side session. Keep API tokens on the server; browser code should use the Nuxt routes rather than call the API with a token directly.

## Build and Tests

Build the .NET solution:

```sh
dotnet build MiniCrm.slnx
```

Run the .NET tests:

```sh
dotnet test MiniCrm.slnx
```

Build the web client:

```sh
cd src/Web
bun run build
```
