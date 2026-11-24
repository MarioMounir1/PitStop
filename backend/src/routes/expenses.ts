import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { HttpError } from '../middleware/errorHandler';
import { expenseSchema, expenseUpdateSchema } from '../schemas/models';
import { TorqDataStore } from '../services/torqStore';

export function createExpensesRouter(store: TorqDataStore): Router {
  const router = Router();

  router.get('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const vehicleId =
        typeof req.query.vehicleId === 'string'
          ? req.query.vehicleId
          : undefined;
      const expenses = await store.listExpenses(req.uid!, vehicleId);
      res.json({ data: expenses });
    } catch (err) {
      next(err);
    }
  });

  router.post('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const payload = expenseSchema.parse(req.body);
      const saved = await store.upsertExpense(req.uid!, payload);
      res.status(201).json({ data: saved });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const patch = expenseUpdateSchema.parse(req.body);
      const updated = await store.updateExpense(
        req.uid!,
        String(req.params.id),
        patch,
      );
      if (!updated) {
        throw new HttpError(404, 'Expense not found.');
      }
      res.json({ data: updated });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const deleted = await store.deleteExpense(
        req.uid!,
        String(req.params.id),
      );
      if (!deleted) {
        throw new HttpError(404, 'Expense not found.');
      }
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
