import { v } from "convex/values";
import { query, mutation, internalMutation } from "./_generated/server";
import { requireAdmin } from "./lib/auth";

// Check if the current user is an admin (used by the admin layout to gate access)
export const isAdmin = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return false;

    const admin = await ctx.db
      .query("adminUsers")
      .withIndex("by_clerk_user_id", (q) =>
        q.eq("clerkUserId", identity.subject)
      )
      .first();

    return admin?.isActive === true;
  },
});

// Dashboard stats
export const getStats = query({
  args: {},
  handler: async (ctx) => {
    await requireAdmin(ctx);

    const allUsers = await ctx.db.query("users").take(10000);
    const allSubs = await ctx.db.query("subscriptions").take(10000);

    const totalUsers = allUsers.length;
    const active = allSubs.filter((s) => s.status === "active").length;
    const trialing = allSubs.filter((s) => s.status === "trialing").length;
    const pastDue = allSubs.filter((s) => s.status === "past_due").length;
    const canceled = allSubs.filter((s) => s.status === "canceled").length;
    const mrr = active * 9.99;

    return { totalUsers, active, trialing, pastDue, canceled, mrr };
  },
});

// List all customers with their subscription status
export const listCustomers = query({
  args: {},
  handler: async (ctx) => {
    await requireAdmin(ctx);

    const users = await ctx.db.query("users").order("desc").take(200);

    const customers = await Promise.all(
      users.map(async (user) => {
        const subscription = await ctx.db
          .query("subscriptions")
          .withIndex("by_user", (q) => q.eq("userId", user._id))
          .first();

        return {
          _id: user._id,
          name: user.name || "—",
          email: user.email,
          clerkId: user.clerkId,
          createdAt: user.createdAt,
          subscription: subscription
            ? {
                status: subscription.status,
                trialEndsAt: subscription.trialEndsAt,
                currentPeriodEnd: subscription.currentPeriodEnd,
                stripeCustomerId: subscription.stripeCustomerId,
                stripeSubscriptionId: subscription.stripeSubscriptionId,
              }
            : null,
        };
      })
    );

    return customers;
  },
});

// Get a single customer with full details
export const getCustomer = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await requireAdmin(ctx);

    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("Customer not found");

    const subscription = await ctx.db
      .query("subscriptions")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .first();

    return {
      ...user,
      subscription: subscription ?? null,
    };
  },
});

// Update a customer's profile (admin only)
export const updateCustomer = mutation({
  args: {
    userId: v.id("users"),
    name: v.optional(v.string()),
    email: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await requireAdmin(ctx);
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("Customer not found");

    const updates: Record<string, string | undefined> = {};
    if (args.name !== undefined) updates.name = args.name;
    if (args.email !== undefined) updates.email = args.email;

    await ctx.db.patch(args.userId, updates);
  },
});

// Delete a customer and their subscription (admin only)
export const deleteCustomer = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await requireAdmin(ctx);
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("Customer not found");

    // Delete subscription if exists
    const sub = await ctx.db
      .query("subscriptions")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .first();
    if (sub) await ctx.db.delete(sub._id);

    // Delete user
    await ctx.db.delete(args.userId);
  },
});

// Internal mutation for CLI-only admin seeding.
// Run: npx convex run admin:seedAdminInternal '{"clerkUserId":"...","email":"..."}'
export const seedAdminInternal = internalMutation({
  args: {
    clerkUserId: v.string(),
    email: v.string(),
  },
  handler: async (ctx, args) => {
    // Delete any existing admin records first
    const existing = await ctx.db.query("adminUsers").take(100);
    for (const record of existing) {
      await ctx.db.delete(record._id);
    }

    return await ctx.db.insert("adminUsers", {
      clerkUserId: args.clerkUserId,
      email: args.email,
      role: "super_admin",
      isActive: true,
      createdAt: Date.now(),
    });
  },
});
