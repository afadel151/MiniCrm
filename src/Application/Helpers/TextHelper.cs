
using System.Net.Mail;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Core.Exceptions;

namespace MiniCrm.Application.Helpers;
public static class TextHelper
{
    public static string Required(string? v, string field, int min, int max)
    {
        var s = string.Join(' ', (v ?? "").Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (s.Length < min || s.Length > max)
            throw new ValidationDomainException($"{field} must be between {min} and {max} characters.");
        return s;
    }

    public static string? Optional(string? v, string field, int max)
    {
        var s = v?.Trim();
        if (string.IsNullOrEmpty(s)) return null;
        if (s.Length > max) throw new ValidationDomainException($"{field} must be at most {max} characters.");
        return s;
    }

    /// <summary>Only http(s) survives: a stored "javascript:" URL rendered as a link is stored XSS.</summary>
    public static string? Website(string? v)
    {
        var s = Optional(v, "Website", 200);
        if (s is null) return null;
        if (!s.Contains("://")) s = "https://" + s;
        if (!Uri.TryCreate(s, UriKind.Absolute, out var u) || u.Scheme is not ("http" or "https") || string.IsNullOrEmpty(u.Host))
            throw new ValidationDomainException("Website must be a valid http(s) address."); 
        return u.AbsoluteUri.TrimEnd('/');
    }

    public static string? Email(string? v)
    {
        var s = Optional(v, "Email", 254);
        if (s is null) return null;
        if (!MailAddress.TryCreate(s, out var a) || a.Address != s)
            throw new ValidationDomainException("Email is not valid.");
        return s.ToLowerInvariant();
    }

    public static bool IsUniqueViolation(DbUpdateException ex) =>
        ex.InnerException is SqlException { Number: 2601 or 2627 };
}