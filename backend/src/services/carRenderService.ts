import { GoogleGenAI } from '@google/genai';
import { CarAngleKey, GenerateCarViewRequest } from '../schemas/models';

export interface CarViewRenderResult {
  angle: CarAngleKey;
  mimeType: string;
  imageBase64: string;
  model: string;
}

export interface CarViewRenderer {
  generateAngle(req: GenerateCarViewRequest): Promise<CarViewRenderResult>;
}

const ANGLE_DESCRIPTIONS: Record<CarAngleKey, string> = {
  front: 'direct eye-level front view, centered symmetrical headlights and grille',
  front_3_4: 'front right 3/4 studio angle (45 degrees clockwise), showing front fascia and right side profile',
  side: 'pure right-side profile studio view (90 degrees), full wheelbase centered horizontally',
  rear_3_4: 'rear right 3/4 studio angle (135 degrees), showing rear taillights and right quarter panel',
  rear: 'direct eye-level rear view (180 degrees), centered taillights and rear bumper',
  rear_3_4_l: 'rear left 3/4 studio angle (225 degrees), showing rear taillights and left quarter panel',
  side_l: 'pure left-side profile studio view (270 degrees), full wheelbase centered horizontally facing left',
  front_3_4_l: 'front left 3/4 studio angle (315 degrees), showing front fascia and left side profile',
};

export class GeminiCarViewRenderer implements CarViewRenderer {
  private readonly model: string;

  constructor(model?: string) {
    this.model =
      model || process.env.GEMINI_IMAGE_MODEL || 'gemini-nano-banana-2.1';
  }

  private createClient(): GoogleGenAI {
    const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
    if (!apiKey || apiKey === 'your-gemini-api-key') {
      throw new Error(
        'GEMINI_API_KEY is not configured on the PitStop backend.',
      );
    }
    return new GoogleGenAI({ apiKey });
  }

  async generateAngle(
    req: GenerateCarViewRequest,
  ): Promise<CarViewRenderResult> {
    const ai = this.createClient();
    const angleDesc = ANGLE_DESCRIPTIONS[req.angle];
    const carDesc = `${req.year} ${req.make} ${req.model} in ${req.color} paint`;

    const baseStudioStyle =
      'Clean dark obsidian automotive studio background (#0E1117), subtle soft floor shadow, sleek studio rim lighting, photorealistic showroom turntable render, no text, no watermarks, no license plate letters, entire car centered in frame.';

    const interaction = req.referenceImageBase64
      ? await ai.interactions.create({
          model: this.model,
          input: [
            {
              type: 'text',
              text: `Using the attached reference car image so the exact body trim, wheels, paint finish, and proportions stay identical, render the ${angleDesc} of this ${carDesc}. ${baseStudioStyle}`,
            },
            {
              type: 'image',
              mime_type: (req.referenceMimeType || 'image/png') as
                | 'image/png'
                | 'image/jpeg'
                | 'image/webp',
              data: req.referenceImageBase64,
            },
          ],
        })
      : await ai.interactions.create({
          model: this.model,
          input: `Render the ${angleDesc} of a ${carDesc}. ${baseStudioStyle}`,
        });

    const outputImage = interaction.output_image;
    if (outputImage?.data) {
      return {
        angle: req.angle,
        mimeType: outputImage.mime_type || 'image/png',
        imageBase64: outputImage.data,
        model: this.model,
      };
    }

    // Fallback scan across model_output steps if output_image helper is empty
    for (const step of interaction.steps ?? []) {
      if (step.type === 'model_output' && Array.isArray(step.content)) {
        for (const block of step.content) {
          if (block.type === 'image' && block.data) {
            return {
              angle: req.angle,
              mimeType: block.mime_type || 'image/png',
              imageBase64: block.data,
              model: this.model,
            };
          }
        }
      }
    }

    throw new Error(`Gemini model ${this.model} did not return an image.`);
  }
}
