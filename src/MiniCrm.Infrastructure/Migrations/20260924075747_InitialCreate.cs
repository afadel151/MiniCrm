using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MiniCrm.Infrastructure.Migrations;

/// <inheritdoc />
public partial class InitialCreate : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "AspNetRoles",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())")
                    .Annotation("Relational:DefaultConstraintName", "DF_AspNetRoles_Id"),
                Name = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                NormalizedName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AspNetRoles", x => x.Id);
            });

        migrationBuilder.CreateTable(
            name: "AspNetUsers",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "(newsequentialid())")
                    .Annotation("Relational:DefaultConstraintName", "DF_AspNetUsers_Id"),
                FirstName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                LastName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                IsActive = table.Column<bool>(type: "bit", nullable: false),
                MustChangePassword = table.Column<bool>(type: "bit", nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_AspNetUsers_CreatedAtUtc"),
                LastLoginAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                UserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                NormalizedUserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                NormalizedEmail = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                EmailConfirmed = table.Column<bool>(type: "bit", nullable: false),
                PasswordHash = table.Column<string>(type: "nvarchar(max)", nullable: true),
                SecurityStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                PhoneNumber = table.Column<string>(type: "nvarchar(max)", nullable: true),
                PhoneNumberConfirmed = table.Column<bool>(type: "bit", nullable: false),
                TwoFactorEnabled = table.Column<bool>(type: "bit", nullable: false),
                LockoutEnd = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                LockoutEnabled = table.Column<bool>(type: "bit", nullable: false),
                AccessFailedCount = table.Column<int>(type: "int", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AspNetUsers", x => x.Id);
            });

        migrationBuilder.CreateTable(
            name: "AuditLogs",
            columns: table => new
            {
                Id = table.Column<long>(type: "bigint", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                OccurredAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_AuditLogs_OccurredAtUtc"),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                Action = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                EntityName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                EntityId = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                Details = table.Column<string>(type: "nvarchar(max)", nullable: true),
                IpAddress = table.Column<string>(type: "nvarchar(45)", maxLength: 45, nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AuditLogs", x => x.Id);
                table.CheckConstraint("CK_AuditLogs_DetailsJson", "[Details] IS NULL OR ISJSON([Details]) = 1");
            });

        migrationBuilder.CreateTable(
            name: "PipelineStages",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                SortOrder = table.Column<int>(type: "int", nullable: false),
                DefaultProbability = table.Column<byte>(type: "tinyint", nullable: false),
                IsWon = table.Column<bool>(type: "bit", nullable: false),
                IsLost = table.Column<bool>(type: "bit", nullable: false),
                IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true)
                    .Annotation("Relational:DefaultConstraintName", "DF_PipelineStages_IsActive")
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PipelineStages", x => x.Id);
                table.CheckConstraint("CK_PipelineStages_Probability", "[DefaultProbability] BETWEEN 0 AND 100");
                table.CheckConstraint("CK_PipelineStages_WonLost", "NOT ([IsWon] = 1 AND [IsLost] = 1)");
            });

        migrationBuilder.CreateTable(
            name: "AspNetRoleClaims",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                RoleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AspNetRoleClaims", x => x.Id);
                table.ForeignKey(
                    name: "FK_AspNetRoleClaims_AspNetRoles_RoleId",
                    column: x => x.RoleId,
                    principalTable: "AspNetRoles",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "AspNetUserClaims",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AspNetUserClaims", x => x.Id);
                table.ForeignKey(
                    name: "FK_AspNetUserClaims_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "AspNetUserLogins",
            columns: table => new
            {
                LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                ProviderKey = table.Column<string>(type: "nvarchar(450)", nullable: false),
                ProviderDisplayName = table.Column<string>(type: "nvarchar(max)", nullable: true),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AspNetUserLogins", x => new { x.LoginProvider, x.ProviderKey });
                table.ForeignKey(
                    name: "FK_AspNetUserLogins_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "AspNetUserRoles",
            columns: table => new
            {
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                RoleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AspNetUserRoles", x => new { x.UserId, x.RoleId });
                table.ForeignKey(
                    name: "FK_AspNetUserRoles_AspNetRoles_RoleId",
                    column: x => x.RoleId,
                    principalTable: "AspNetRoles",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_AspNetUserRoles_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "AspNetUserTokens",
            columns: table => new
            {
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                Name = table.Column<string>(type: "nvarchar(450)", nullable: false),
                Value = table.Column<string>(type: "nvarchar(max)", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_AspNetUserTokens", x => new { x.UserId, x.LoginProvider, x.Name });
                table.ForeignKey(
                    name: "FK_AspNetUserTokens_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "Companies",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                Website = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_Companies_CreatedAtUtc"),
                CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                DeletedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Companies", x => x.Id);
                table.CheckConstraint("CK_Companies_Deleted", "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)");
                table.ForeignKey(
                    name: "FK_Companies_AspNetUsers_CreatedByUserId",
                    column: x => x.CreatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Companies_AspNetUsers_UpdatedByUserId",
                    column: x => x.UpdatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
            });

        migrationBuilder.CreateTable(
            name: "Conversations",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                IsGroup = table.Column<bool>(type: "bit", nullable: false),
                Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                DirectKey = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true),
                CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_Conversations_CreatedAtUtc")
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Conversations", x => x.Id);
                table.CheckConstraint("CK_Conversations_Kind", "([IsGroup] = 1 AND [DirectKey] IS NULL) OR ([IsGroup] = 0 AND [DirectKey] IS NOT NULL)");
                table.ForeignKey(
                    name: "FK_Conversations_AspNetUsers_CreatedByUserId",
                    column: x => x.CreatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
            });

        migrationBuilder.CreateTable(
            name: "RefreshTokens",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                TokenHash = table.Column<string>(type: "char(64)", unicode: false, fixedLength: true, maxLength: 64, nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_RefreshTokens_CreatedAtUtc"),
                ExpiresAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                CreatedByIp = table.Column<string>(type: "nvarchar(45)", maxLength: 45, nullable: true),
                RevokedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                ReplacedByTokenHash = table.Column<string>(type: "char(64)", unicode: false, fixedLength: true, maxLength: 64, nullable: true),
                RevokedReason = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_RefreshTokens", x => x.Id);
                table.ForeignKey(
                    name: "FK_RefreshTokens_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "Contacts",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                FirstName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                LastName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                Phone = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                CompanyId = table.Column<int>(type: "int", nullable: true),
                AddressLine = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                City = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                PostalCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                Country = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_Contacts_CreatedAtUtc"),
                CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                DeletedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Contacts", x => x.Id);
                table.CheckConstraint("CK_Contacts_Deleted", "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)");
                table.ForeignKey(
                    name: "FK_Contacts_AspNetUsers_CreatedByUserId",
                    column: x => x.CreatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Contacts_AspNetUsers_UpdatedByUserId",
                    column: x => x.UpdatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Contacts_Companies_CompanyId",
                    column: x => x.CompanyId,
                    principalTable: "Companies",
                    principalColumn: "Id");
            });

        migrationBuilder.CreateTable(
            name: "ConversationParticipants",
            columns: table => new
            {
                ConversationId = table.Column<int>(type: "int", nullable: false),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                JoinedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_ConvParticipants_JoinedAtUtc"),
                LastReadMessageId = table.Column<long>(type: "bigint", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_ConversationParticipants", x => new { x.ConversationId, x.UserId });
                table.ForeignKey(
                    name: "FK_ConvParticipants_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_ConvParticipants_Conversations_ConversationId",
                    column: x => x.ConversationId,
                    principalTable: "Conversations",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "Messages",
            columns: table => new
            {
                Id = table.Column<long>(type: "bigint", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                ConversationId = table.Column<int>(type: "int", nullable: false),
                SenderUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Body = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                SentAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_Messages_SentAtUtc"),
                EditedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                IsDeleted = table.Column<bool>(type: "bit", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Messages", x => x.Id);
                table.CheckConstraint("CK_Messages_BodyNotEmpty", "LEN(LTRIM(RTRIM([Body]))) > 0");
                table.ForeignKey(
                    name: "FK_Messages_AspNetUsers_SenderUserId",
                    column: x => x.SenderUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Messages_Conversations_ConversationId",
                    column: x => x.ConversationId,
                    principalTable: "Conversations",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "Opportunities",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                ContactId = table.Column<int>(type: "int", nullable: false),
                OwnerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                StageId = table.Column<int>(type: "int", nullable: false),
                Amount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                Probability = table.Column<byte>(type: "tinyint", nullable: false),
                ExpectedCloseDate = table.Column<DateOnly>(type: "date", nullable: true),
                ClosedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                LostReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_Opportunities_CreatedAtUtc"),
                CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                UpdatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                DeletedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Opportunities", x => x.Id);
                table.CheckConstraint("CK_Opportunities_Amount", "[Amount] >= 0");
                table.CheckConstraint("CK_Opportunities_Deleted", "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)");
                table.CheckConstraint("CK_Opportunities_Probability", "[Probability] BETWEEN 0 AND 100");
                table.ForeignKey(
                    name: "FK_Opportunities_AspNetUsers_CreatedByUserId",
                    column: x => x.CreatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Opportunities_AspNetUsers_OwnerUserId",
                    column: x => x.OwnerUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Opportunities_AspNetUsers_UpdatedByUserId",
                    column: x => x.UpdatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Opportunities_Contacts_ContactId",
                    column: x => x.ContactId,
                    principalTable: "Contacts",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Opportunities_PipelineStages_StageId",
                    column: x => x.StageId,
                    principalTable: "PipelineStages",
                    principalColumn: "Id");
            });

        migrationBuilder.CreateTable(
            name: "Interactions",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                ContactId = table.Column<int>(type: "int", nullable: false),
                OpportunityId = table.Column<int>(type: "int", nullable: true),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                InteractionType = table.Column<byte>(type: "tinyint", nullable: false),
                OccurredAtUtc = table.Column<DateTime>(type: "datetime2(0)", precision: 0, nullable: false),
                Subject = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                Notes = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_Interactions_CreatedAtUtc"),
                UpdatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Interactions", x => x.Id);
                table.CheckConstraint("CK_Interactions_Type", "[InteractionType] IN (1, 2, 3)");
                table.ForeignKey(
                    name: "FK_Interactions_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Interactions_Contacts_ContactId",
                    column: x => x.ContactId,
                    principalTable: "Contacts",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_Interactions_Opportunities_OpportunityId",
                    column: x => x.OpportunityId,
                    principalTable: "Opportunities",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.SetNull);
            });

        migrationBuilder.CreateTable(
            name: "OpportunityStageHistory",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                OpportunityId = table.Column<int>(type: "int", nullable: false),
                FromStageId = table.Column<int>(type: "int", nullable: true),
                ToStageId = table.Column<int>(type: "int", nullable: false),
                ChangedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                ChangedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_OppStageHistory_ChangedAtUtc")
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_OpportunityStageHistory", x => x.Id);
                table.ForeignKey(
                    name: "FK_OppStageHistory_AspNetUsers_ChangedByUserId",
                    column: x => x.ChangedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_OppStageHistory_Opportunities_OpportunityId",
                    column: x => x.OpportunityId,
                    principalTable: "Opportunities",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_OppStageHistory_PipelineStages_FromStageId",
                    column: x => x.FromStageId,
                    principalTable: "PipelineStages",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_OppStageHistory_PipelineStages_ToStageId",
                    column: x => x.ToStageId,
                    principalTable: "PipelineStages",
                    principalColumn: "Id");
            });

        migrationBuilder.CreateTable(
            name: "Reminders",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                ContactId = table.Column<int>(type: "int", nullable: false),
                OpportunityId = table.Column<int>(type: "int", nullable: true),
                AssignedUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                InteractionType = table.Column<byte>(type: "tinyint", nullable: false),
                Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                Notes = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                DueAtUtc = table.Column<DateTime>(type: "datetime2(0)", precision: 0, nullable: false),
                Status = table.Column<byte>(type: "tinyint", nullable: false),
                NotifiedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                CompletedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_Reminders_CreatedAtUtc"),
                RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Reminders", x => x.Id);
                table.CheckConstraint("CK_Reminders_Completed", "([Status] = 1 AND [CompletedAtUtc] IS NOT NULL) OR ([Status] <> 1 AND [CompletedAtUtc] IS NULL)");
                table.CheckConstraint("CK_Reminders_Status", "[Status] IN (0, 1, 2)");
                table.CheckConstraint("CK_Reminders_Type", "[InteractionType] IN (1, 2, 3)");
                table.ForeignKey(
                    name: "FK_Reminders_AspNetUsers_AssignedUserId",
                    column: x => x.AssignedUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Reminders_AspNetUsers_CreatedByUserId",
                    column: x => x.CreatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_Reminders_Contacts_ContactId",
                    column: x => x.ContactId,
                    principalTable: "Contacts",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_Reminders_Opportunities_OpportunityId",
                    column: x => x.OpportunityId,
                    principalTable: "Opportunities",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.SetNull);
            });

        migrationBuilder.CreateIndex(
            name: "IX_AspNetRoleClaims_RoleId",
            table: "AspNetRoleClaims",
            column: "RoleId");

        migrationBuilder.CreateIndex(
            name: "RoleNameIndex",
            table: "AspNetRoles",
            column: "NormalizedName",
            unique: true,
            filter: "[NormalizedName] IS NOT NULL");

        migrationBuilder.CreateIndex(
            name: "IX_AspNetUserClaims_UserId",
            table: "AspNetUserClaims",
            column: "UserId");

        migrationBuilder.CreateIndex(
            name: "IX_AspNetUserLogins_UserId",
            table: "AspNetUserLogins",
            column: "UserId");

        migrationBuilder.CreateIndex(
            name: "IX_AspNetUserRoles_RoleId",
            table: "AspNetUserRoles",
            column: "RoleId");

        migrationBuilder.CreateIndex(
            name: "EmailIndex",
            table: "AspNetUsers",
            column: "NormalizedEmail");

        migrationBuilder.CreateIndex(
            name: "UserNameIndex",
            table: "AspNetUsers",
            column: "NormalizedUserName",
            unique: true,
            filter: "[NormalizedUserName] IS NOT NULL");

        migrationBuilder.CreateIndex(
            name: "IX_AuditLogs_Entity",
            table: "AuditLogs",
            columns: ["EntityName", "EntityId"]);

        migrationBuilder.CreateIndex(
            name: "IX_AuditLogs_OccurredAtUtc",
            table: "AuditLogs",
            column: "OccurredAtUtc",
            descending: []);

        migrationBuilder.CreateIndex(
            name: "IX_AuditLogs_UserId",
            table: "AuditLogs",
            column: "UserId",
            filter: "([UserId] IS NOT NULL)");

        migrationBuilder.CreateIndex(
            name: "IX_Companies_CreatedByUserId",
            table: "Companies",
            column: "CreatedByUserId");

        migrationBuilder.CreateIndex(
            name: "IX_Companies_UpdatedByUserId",
            table: "Companies",
            column: "UpdatedByUserId",
            filter: "([UpdatedByUserId] IS NOT NULL)");

        migrationBuilder.CreateIndex(
            name: "UX_Companies_Name",
            table: "Companies",
            column: "Name",
            unique: true,
            filter: "([IsDeleted]=(0))");

        migrationBuilder.CreateIndex(
            name: "IX_Contacts_CompanyId",
            table: "Contacts",
            column: "CompanyId");

        migrationBuilder.CreateIndex(
            name: "IX_Contacts_CreatedByUserId",
            table: "Contacts",
            column: "CreatedByUserId");

        migrationBuilder.CreateIndex(
            name: "IX_Contacts_LastName_FirstName",
            table: "Contacts",
            columns: ["LastName", "FirstName"],
            filter: "([IsDeleted]=(0))");

        migrationBuilder.CreateIndex(
            name: "IX_Contacts_UpdatedByUserId",
            table: "Contacts",
            column: "UpdatedByUserId",
            filter: "([UpdatedByUserId] IS NOT NULL)");

        migrationBuilder.CreateIndex(
            name: "UX_Contacts_Email",
            table: "Contacts",
            column: "Email",
            unique: true,
            filter: "([Email] IS NOT NULL AND [IsDeleted]=(0))");

        migrationBuilder.CreateIndex(
            name: "IX_ConvParticipants_UserId",
            table: "ConversationParticipants",
            column: "UserId");

        migrationBuilder.CreateIndex(
            name: "IX_Conversations_CreatedByUserId",
            table: "Conversations",
            column: "CreatedByUserId");

        migrationBuilder.CreateIndex(
            name: "UX_Conversations_DirectKey",
            table: "Conversations",
            column: "DirectKey",
            unique: true,
            filter: "([DirectKey] IS NOT NULL)");

        migrationBuilder.CreateIndex(
            name: "IX_Interactions_ContactId_OccurredAtUtc",
            table: "Interactions",
            columns: ["ContactId", "OccurredAtUtc"],
            descending: [false, true]);

        migrationBuilder.CreateIndex(
            name: "IX_Interactions_OpportunityId",
            table: "Interactions",
            column: "OpportunityId",
            filter: "([OpportunityId] IS NOT NULL)");

        migrationBuilder.CreateIndex(
            name: "IX_Interactions_UserId_OccurredAtUtc",
            table: "Interactions",
            columns: ["UserId", "OccurredAtUtc"],
            descending: [false, true]);

        migrationBuilder.CreateIndex(
            name: "IX_Messages_ConversationId_Id",
            table: "Messages",
            columns: ["ConversationId", "Id"],
            descending: [false, true]);

        migrationBuilder.CreateIndex(
            name: "IX_Messages_SenderUserId",
            table: "Messages",
            column: "SenderUserId");

        migrationBuilder.CreateIndex(
            name: "IX_Opportunities_ContactId",
            table: "Opportunities",
            column: "ContactId");

        migrationBuilder.CreateIndex(
            name: "IX_Opportunities_CreatedByUserId",
            table: "Opportunities",
            column: "CreatedByUserId");

        migrationBuilder.CreateIndex(
            name: "IX_Opportunities_ExpectedCloseDate",
            table: "Opportunities",
            column: "ExpectedCloseDate",
            filter: "([IsDeleted]=(0) AND [ExpectedCloseDate] IS NOT NULL)");

        migrationBuilder.CreateIndex(
            name: "IX_Opportunities_OwnerUserId",
            table: "Opportunities",
            column: "OwnerUserId",
            filter: "([IsDeleted]=(0))");

        migrationBuilder.CreateIndex(
            name: "IX_Opportunities_StageId",
            table: "Opportunities",
            column: "StageId",
            filter: "([IsDeleted]=(0))");

        migrationBuilder.CreateIndex(
            name: "IX_Opportunities_UpdatedByUserId",
            table: "Opportunities",
            column: "UpdatedByUserId");

        migrationBuilder.CreateIndex(
            name: "IX_OppStageHistory_ChangedByUserId",
            table: "OpportunityStageHistory",
            column: "ChangedByUserId");

        migrationBuilder.CreateIndex(
            name: "IX_OppStageHistory_FromStageId",
            table: "OpportunityStageHistory",
            column: "FromStageId",
            filter: "([FromStageId] IS NOT NULL)");

        migrationBuilder.CreateIndex(
            name: "IX_OppStageHistory_OpportunityId_ChangedAtUtc",
            table: "OpportunityStageHistory",
            columns: ["OpportunityId", "ChangedAtUtc"]);

        migrationBuilder.CreateIndex(
            name: "IX_OppStageHistory_ToStageId",
            table: "OpportunityStageHistory",
            column: "ToStageId");

        migrationBuilder.CreateIndex(
            name: "UX_PipelineStages_Name",
            table: "PipelineStages",
            column: "Name",
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_RefreshTokens_UserId",
            table: "RefreshTokens",
            column: "UserId");

        migrationBuilder.CreateIndex(
            name: "UX_RefreshTokens_TokenHash",
            table: "RefreshTokens",
            column: "TokenHash",
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_Reminders_AssignedUserId_Status_DueAtUtc",
            table: "Reminders",
            columns: ["AssignedUserId", "Status", "DueAtUtc"]);

        migrationBuilder.CreateIndex(
            name: "IX_Reminders_ContactId",
            table: "Reminders",
            column: "ContactId");

        migrationBuilder.CreateIndex(
            name: "IX_Reminders_CreatedByUserId",
            table: "Reminders",
            column: "CreatedByUserId");

        migrationBuilder.CreateIndex(
            name: "IX_Reminders_DueScan",
            table: "Reminders",
            column: "DueAtUtc",
            filter: "([Status]=(0) AND [NotifiedAtUtc] IS NULL)");

        migrationBuilder.CreateIndex(
            name: "IX_Reminders_OpportunityId",
            table: "Reminders",
            column: "OpportunityId",
            filter: "([OpportunityId] IS NOT NULL)");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "AspNetRoleClaims");

        migrationBuilder.DropTable(
            name: "AspNetUserClaims");

        migrationBuilder.DropTable(
            name: "AspNetUserLogins");

        migrationBuilder.DropTable(
            name: "AspNetUserRoles");

        migrationBuilder.DropTable(
            name: "AspNetUserTokens");

        migrationBuilder.DropTable(
            name: "AuditLogs");

        migrationBuilder.DropTable(
            name: "ConversationParticipants");

        migrationBuilder.DropTable(
            name: "Interactions");

        migrationBuilder.DropTable(
            name: "Messages");

        migrationBuilder.DropTable(
            name: "OpportunityStageHistory");

        migrationBuilder.DropTable(
            name: "RefreshTokens");

        migrationBuilder.DropTable(
            name: "Reminders");

        migrationBuilder.DropTable(
            name: "AspNetRoles");

        migrationBuilder.DropTable(
            name: "Conversations");

        migrationBuilder.DropTable(
            name: "Opportunities");

        migrationBuilder.DropTable(
            name: "Contacts");

        migrationBuilder.DropTable(
            name: "PipelineStages");

        migrationBuilder.DropTable(
            name: "Companies");

        migrationBuilder.DropTable(
            name: "AspNetUsers");
    }
}
