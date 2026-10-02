using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MiniCrm.Infrastructure.Migrations;

/// <inheritdoc />
public partial class AddInvitationsTable : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "FK_Contacts_AspNetUsers_UpdatedByUserId",
            table: "Contacts");

        migrationBuilder.DropForeignKey(
            name: "FK_Requests_AspNetUsers_CreatedByUserId",
            table: "Requests");
        migrationBuilder.DropIndex(
            name: "IX_Contacts_UpdatedByUserId",
            table: "Contacts");
        migrationBuilder.AlterColumn<Guid>(
            name: "UpdatedByUserId",
            table: "Contacts",
            type: "uniqueidentifier",
            nullable: true,
            oldClrType: typeof(Guid),
            oldType: "uniqueidentifier");
        migrationBuilder.CreateIndex(
            name: "IX_Contacts_UpdatedByUserId",
            table: "Contacts",
            column: "UpdatedByUserId",
            filter: "([UpdatedByUserId] IS NOT NULL)");
        migrationBuilder.CreateTable(
            name: "BusinessInvitations",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                BusinessId = table.Column<int>(type: "int", nullable: false),
                Email = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: false),
                NormalizedEmail = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: false),
                Role = table.Column<byte>(type: "tinyint", nullable: false),
                TokenHash = table.Column<string>(type: "nchar(64)", fixedLength: true, maxLength: 64, nullable: false),
                Status = table.Column<int>(type: "int", nullable: false),
                InvitedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                ExpiresAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                AcceptedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                AcceptedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                RevokedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_BusinessInvitations", x => x.Id);
                table.ForeignKey(
                    name: "FK_BusinessInvitations_AspNetUsers_InvitedByUserId",
                    column: x => x.InvitedByUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
                table.ForeignKey(
                    name: "FK_BusinessInvitations_Businesses_BusinessId",
                    column: x => x.BusinessId,
                    principalTable: "Businesses",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_BusinessInvitations_BusinessId_NormalizedEmail",
            table: "BusinessInvitations",
            columns: ["BusinessId", "NormalizedEmail"],
            unique: true,
            filter: "[Status] = 0");

        migrationBuilder.CreateIndex(
            name: "IX_BusinessInvitations_InvitedByUserId",
            table: "BusinessInvitations",
            column: "InvitedByUserId");

        migrationBuilder.CreateIndex(
            name: "IX_BusinessInvitations_TokenHash",
            table: "BusinessInvitations",
            column: "TokenHash",
            unique: true);

        migrationBuilder.AddForeignKey(
            name: "FK_Contacts_AspNetUsers_UpdatedByUserId",
            table: "Contacts",
            column: "UpdatedByUserId",
            principalTable: "AspNetUsers",
            principalColumn: "Id");

        migrationBuilder.AddForeignKey(
            name: "FK_Requests_AspNetUsers_CreatedByUserId",
            table: "Requests",
            column: "CreatedByUserId",
            principalTable: "AspNetUsers",
            principalColumn: "Id");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "FK_Contacts_AspNetUsers_UpdatedByUserId",
            table: "Contacts");

        migrationBuilder.DropForeignKey(
            name: "FK_Requests_AspNetUsers_CreatedByUserId",
            table: "Requests");

        migrationBuilder.DropTable(
            name: "BusinessInvitations");

        migrationBuilder.AlterColumn<Guid>(
            name: "UpdatedByUserId",
            table: "Contacts",
            type: "uniqueidentifier",
            nullable: false,
            defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
            oldClrType: typeof(Guid),
            oldType: "uniqueidentifier",
            oldNullable: true);

        migrationBuilder.AddForeignKey(
            name: "FK_Contacts_AspNetUsers_UpdatedByUserId",
            table: "Contacts",
            column: "UpdatedByUserId",
            principalTable: "AspNetUsers",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);

        migrationBuilder.AddForeignKey(
            name: "FK_Requests_AspNetUsers_CreatedByUserId",
            table: "Requests",
            column: "CreatedByUserId",
            principalTable: "AspNetUsers",
            principalColumn: "Id",
            onDelete: ReferentialAction.Cascade);
    }
}
