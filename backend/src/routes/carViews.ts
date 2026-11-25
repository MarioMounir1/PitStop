import { Router } from 'express';
import { generateCarViewRequestSchema } from '../schemas/models';
import { CarViewRenderer } from '../services/carRenderService';

export function createCarViewsRouter(renderer: CarViewRenderer): Router {
  const router = Router();

  router.post('/generate', async (req, res, next) => {
    try {
      const payload = generateCarViewRequestSchema.parse(req.body);
      const result = await renderer.generateAngle(payload);
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
