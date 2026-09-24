using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MiniCrm.Infrastructure.Migrations;

/// <inheritdoc />
public partial class AddSellerRatings : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "SellerRatings",
            columns: table => new
            {
                Id = table.Column<int>(type: "int", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                SellerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                ClientUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Stars = table.Column<byte>(type: "tinyint", nullable: false),
                Comment = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: false, defaultValueSql: "(sysutcdatetime())")
                    .Annotation("Relational:DefaultConstraintName", "DF_SellerRatings_CreatedAtUtc"),
                UpdatedAtUtc = table.Column<DateTime>(type: "datetime2(3)", precision: 3, nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SellerRatings", x => x.Id);
                table.CheckConstraint("CK_SellerRatings_NotSelf", "[SellerUserId] <> [ClientUserId]");
                table.CheckConstraint("CK_SellerRatings_Stars", "[Stars] BETWEEN 1 AND 5");
                table.ForeignKey(
                    name: "FK_SellerRatings_AspNetUsers_ClientUserId",
                    column: x => x.ClientUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
                table.ForeignKey(
                    name: "FK_SellerRatings_AspNetUsers_SellerUserId",
                    column: x => x.SellerUserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateIndex(
            name: "IX_SellerRatings_ClientUserId",
            table: "SellerRatings",
            column: "ClientUserId");

        migrationBuilder.CreateIndex(
            name: "UX_SellerRatings_Seller_Client",
            table: "SellerRatings",
            columns: ["SellerUserId", "ClientUserId"],
            unique: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "SellerRatings");
    }
}
