using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MiniCrm.Infrastructure.Migrations;

/// <inheritdoc />
public partial class AddRequestsTable : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<int>(
            name: "ContactSource",
            table: "Contacts",
            type: "int",
            nullable: false,
            defaultValue: 0);

        migrationBuilder.AddColumn<int>(
            name: "ContactType",
            table: "Contacts",
            type: "int",
            nullable: false,
            defaultValue: 0);

        migrationBuilder.AddColumn<string>(
            name: "Adress",
            table: "Businesses",
            type: "nvarchar(200)",
            maxLength: 200,
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "Domain",
            table: "Businesses",
            type: "int",
            nullable: false,
            defaultValue: 0);

        migrationBuilder.CreateTable(
            name: "Requests",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                Notes = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                ContactId = table.Column<int>(type: "int", nullable: true),
                CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Origin = table.Column<byte>(type: "tinyint", nullable: false),
                Status = table.Column<byte>(type: "tinyint", nullable: false),
                Priority = table.Column<byte>(type: "tinyint", nullable: false),
                DueAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false),
                IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                DeletedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true),
                RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Requests", x => x.Id);
                table.CheckConstraint("CK_Request_Deleted", "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)");
                table.CheckConstraint("CK_Request_Origin", "[Origin] IN (0,1, 2, 3,4,99)");
                table.CheckConstraint("CK_Request_Priority", "[Priority] IN (0,1, 2)");
                table.CheckConstraint("CK_Request_Status", "[Status] IN (0,1, 2, 3,4)");
                table.ForeignKey(
                    name: "FK_Requests_AspNetUsers_CreatedByUserId",
                    column: x => x.CreatedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_Requests_Contacts_ContactId",
                    column: x => x.ContactId,
                    principalTable: "Contacts",
                    principalColumn: "Id");
            });

        migrationBuilder.CreateIndex(
            name: "IX_Request_ContactId",
            table: "Requests",
            column: "ContactId");

        migrationBuilder.CreateIndex(
            name: "IX_Requests_CreatedByUserId",
            table: "Requests",
            column: "CreatedByUserId");

        migrationBuilder.CreateIndex(
            name: "UX_Request_Title",
            table: "Requests",
            column: "Title",
            unique: true,
            filter: "([IsDeleted]=(0))");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "Requests");

        migrationBuilder.DropColumn(
            name: "ContactSource",
            table: "Contacts");

        migrationBuilder.DropColumn(
            name: "ContactType",
            table: "Contacts");

        migrationBuilder.DropColumn(
            name: "Adress",
            table: "Businesses");

        migrationBuilder.DropColumn(
            name: "Domain",
            table: "Businesses");
    }
}
