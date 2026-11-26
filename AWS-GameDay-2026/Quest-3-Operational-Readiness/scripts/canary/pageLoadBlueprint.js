// Canary de CloudWatch Synthetics equivalente al blueprint "Heartbeat monitoring".
// Carga la URL de la aplicación y falla si el código HTTP no es 2xx.
// En el zip tiene que ir en nodejs/node_modules/pageLoadBlueprint.js (handler: pageLoadBlueprint.handler).
const { URL } = require('url');
const synthetics = require('Synthetics');
const log = require('SyntheticsLogger');

const syntheticsConfiguration = synthetics.getConfiguration();

const loadUrl = async function (page, url) {
  const stepName = new URL(url).hostname;
  await synthetics.executeStep(stepName, async function () {
    const response = await page.goto(url, { waitUntil: ['domcontentloaded'], timeout: 30000 });
    if (!response) {
      throw new Error(`Sin respuesta de ${url}`);
    }
    const status = response.status();
    log.info(`${url} -> ${status}`);
    if (status < 200 || status > 299) {
      throw new Error(`Código ${status} al cargar ${url}`);
    }
  });
};

const heartbeat = async function () {
  // La URL se pasa como variable de entorno del canary (RunConfig.EnvironmentVariables.APP_URL)
  const urls = [process.env.APP_URL];
  syntheticsConfiguration.setConfig({
    screenshotOnStepStart: false,
    screenshotOnStepSuccess: true,
    screenshotOnStepFailure: true,
  });
  const page = await synthetics.getPage();
  for (const url of urls) {
    await loadUrl(page, url);
  }
};

exports.handler = async () => {
  return await heartbeat();
};
