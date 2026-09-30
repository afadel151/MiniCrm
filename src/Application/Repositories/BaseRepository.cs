using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Infrastructure.Persistence;

namespace MiniCrm.Application.Repositories;

public interface IBaseRepository<T> where T : class
{
    IQueryable<T> Query(bool asNoTracking = false, bool ignoreQueryFilters = false);
    IQueryable<T> Query(params Expression<Func<T, object>>[] includes);

    Task<List<T>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<T?> GetByIdAsync(params object[] keyValues);
    Task<T?> GetByIdAsync(object[] keyValues, CancellationToken cancellationToken = default);
    Task<List<T>> FindAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default);

    Task<List<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        Func<IQueryable<T>, IOrderedQueryable<T>>? orderBy = null,
        int? skip = null,
        int? take = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default);

    Task<T?> FirstOrDefaultAsync(
        Expression<Func<T, bool>> predicate,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default);

    Task<TResult?> FirstOrDefaultAsync<TResult>(
        Expression<Func<T, bool>> predicate,
        Expression<Func<T, TResult>> selector,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default);

    Task<T?> SingleOrDefaultAsync(
        Expression<Func<T, bool>> predicate,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default);

    Task<bool> AnyAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default);
    Task<int> CountAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken cancellationToken = default);

    Task AddAsync(T entity, bool saveChanges = true, CancellationToken cancellationToken = default);
    Task AddRangeAsync(IEnumerable<T> entities, bool saveChanges = true, CancellationToken cancellationToken = default);
    Task UpdateAsync(T entity, bool saveChanges = true, CancellationToken cancellationToken = default);
    Task UpdateRangeAsync(IEnumerable<T> entities, bool saveChanges = true, CancellationToken cancellationToken = default);
    Task DeleteAsync(T entity, bool saveChanges = true, CancellationToken cancellationToken = default);
    Task DeleteRangeAsync(IEnumerable<T> entities, bool saveChanges = true, CancellationToken cancellationToken = default);
    Task<int> DeleteWhereAsync(Expression<Func<T, bool>> predicate, CancellationToken cancellationToken = default);
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}

public class BaseRepository<T>(AppDbContext context) : IBaseRepository<T> where T : class
{
    private readonly AppDbContext _context = context;
    private readonly DbSet<T> _dbSet = context.Set<T>();

    public virtual IQueryable<T> Query(bool asNoTracking = false, bool ignoreQueryFilters = false)
    {
        IQueryable<T> query = _dbSet;

        if (asNoTracking)
        {
            query = query.AsNoTracking();
        }

        if (ignoreQueryFilters)
        {
            query = query.IgnoreQueryFilters();
        }

        return query;
    }

    public virtual IQueryable<T> Query(params Expression<Func<T, object>>[] includes)
    {
        ArgumentNullException.ThrowIfNull(includes);

        return includes.Aggregate(Query(), (query, include) => query.Include(include));
    }

    public virtual Task<List<T>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return _dbSet.ToListAsync(cancellationToken);
    }

    public virtual async Task<T?> GetByIdAsync(params object[] keyValues)
    {
        ArgumentNullException.ThrowIfNull(keyValues);

        return await _dbSet.FindAsync(keyValues);
    }

    public virtual async Task<T?> GetByIdAsync(object[] keyValues, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(keyValues);
        return await _dbSet.FindAsync(keyValues, cancellationToken);
    }

    public virtual Task<List<T>> FindAsync(
        Expression<Func<T, bool>> predicate,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(predicate);

        return _dbSet.Where(predicate).ToListAsync(cancellationToken);
    }

    public virtual Task<List<T>> ListAsync(
        Expression<Func<T, bool>>? predicate = null,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        Func<IQueryable<T>, IOrderedQueryable<T>>? orderBy = null,
        int? skip = null,
        int? take = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default)
    {
        var query = BuildQuery(predicate, include, orderBy, skip, take, asNoTracking);

        return query.ToListAsync(cancellationToken);
    }

    public virtual Task<T?> FirstOrDefaultAsync(
        Expression<Func<T, bool>> predicate,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(predicate);

        var query = BuildQuery(predicate, include, asNoTracking: asNoTracking);
        return query.FirstOrDefaultAsync(cancellationToken);
    }

    public virtual Task<TResult?> FirstOrDefaultAsync<TResult>(
        Expression<Func<T, bool>> predicate,
        Expression<Func<T, TResult>> selector,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(predicate);
        ArgumentNullException.ThrowIfNull(selector);

        var query = BuildQuery(predicate, include, asNoTracking: asNoTracking);
        return query.Select(selector).FirstOrDefaultAsync(cancellationToken);
    }

    public virtual Task<T?> SingleOrDefaultAsync(
        Expression<Func<T, bool>> predicate,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        bool asNoTracking = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(predicate);

        var query = BuildQuery(predicate, include, asNoTracking: asNoTracking);
        return query.SingleOrDefaultAsync(cancellationToken);
    }

    public virtual Task<bool> AnyAsync(
        Expression<Func<T, bool>> predicate,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(predicate);

        return _dbSet.AnyAsync(predicate, cancellationToken);
    }

    public virtual Task<int> CountAsync(
        Expression<Func<T, bool>>? predicate = null,
        CancellationToken cancellationToken = default)
    {
        return predicate is null
            ? _dbSet.CountAsync(cancellationToken)
            : _dbSet.CountAsync(predicate, cancellationToken);
    }

    public virtual async Task AddAsync(
        T entity,
        bool saveChanges = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entity);

        await _dbSet.AddAsync(entity, cancellationToken);
        await SaveIfRequestedAsync(saveChanges, cancellationToken);
    }

    public virtual async Task AddRangeAsync(
        IEnumerable<T> entities,
        bool saveChanges = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entities);

        await _dbSet.AddRangeAsync(entities, cancellationToken);
        await SaveIfRequestedAsync(saveChanges, cancellationToken);
    }

    public virtual async Task UpdateAsync(
        T entity,
        bool saveChanges = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entity);

        _dbSet.Update(entity);
        await SaveIfRequestedAsync(saveChanges, cancellationToken);
    }

    public virtual async Task UpdateRangeAsync(
        IEnumerable<T> entities,
        bool saveChanges = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entities);

        _dbSet.UpdateRange(entities);
        await SaveIfRequestedAsync(saveChanges, cancellationToken);
    }

    public virtual async Task DeleteAsync(
        T entity,
        bool saveChanges = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entity);

        _dbSet.Remove(entity);
        await SaveIfRequestedAsync(saveChanges, cancellationToken);
    }

    public virtual async Task DeleteRangeAsync(
        IEnumerable<T> entities,
        bool saveChanges = true,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(entities);

        _dbSet.RemoveRange(entities);
        await SaveIfRequestedAsync(saveChanges, cancellationToken);
    }

    public virtual Task<int> DeleteWhereAsync(
        Expression<Func<T, bool>> predicate,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(predicate);

        return _dbSet.Where(predicate).ExecuteDeleteAsync(cancellationToken);
    }

    public virtual Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return _context.SaveChangesAsync(cancellationToken);
    }

    protected virtual IQueryable<T> BuildQuery(
        Expression<Func<T, bool>>? predicate = null,
        Func<IQueryable<T>, IQueryable<T>>? include = null,
        Func<IQueryable<T>, IOrderedQueryable<T>>? orderBy = null,
        int? skip = null,
        int? take = null,
        bool asNoTracking = true)
    {
        var query = Query(asNoTracking);

        if (include is not null)
        {
            query = include(query);
        }

        if (predicate is not null)
        {
            query = query.Where(predicate);
        }

        if (orderBy is not null)
        {
            query = orderBy(query);
        }

        if (skip is not null)
        {
            query = query.Skip(skip.Value);
        }

        if (take is not null)
        {
            query = query.Take(take.Value);
        }

        return query;
    }

    private async Task SaveIfRequestedAsync(bool saveChanges, CancellationToken cancellationToken)
    {
        if (saveChanges)
        {
            await SaveChangesAsync(cancellationToken);
        }
    }
}
