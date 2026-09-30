
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Identity;
using MiniCrm.Application;
using Microsoft.OpenApi;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Services;
using MiniCrm.Core;
using MiniCrm.Infrastructure;
using MiniCrm.Infrastructure.Identity;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/minicrm-.txt", rollingInterval: RollingInterval.Day)
    .CreateLogger();
builder.Host.UseSerilog();


var corsOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? ["http://localhost:5173", "http://localhost:3000"];


builder.Services.AddCors(options =>
{
    options.AddPolicy("SpaAndMobile", policy =>
        policy.WithOrigins(corsOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials());         // needed for cookie auth  Blazor
});
builder.Services.Configure<InvitationOptions>(builder.Configuration.GetSection(InvitationOptions.Section));

builder.Services.AddCore();                                  // Registers Options
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddApplication();

builder.Services.AddControllers();



builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.UseExceptionHandler();

app.UseCors("SpaAndMobile");
app.MapControllers();
app.Run();