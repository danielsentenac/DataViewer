package org.virgo.dataviewer.adapter.servlet;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import org.virgo.dataviewer.adapter.service.DataViewerServices;

public abstract class DataViewerServicesContextListener implements ServletContextListener {
    @Override
    public final void contextInitialized(ServletContextEvent event) {
        ServletContext context = event.getServletContext();
        DataViewerServiceRegistry.registerServices(context, createServices(context));
        DataViewerServiceRegistry.resolveJsonCodec(context);
    }

    @Override
    public void contextDestroyed(ServletContextEvent event) {
        ServletContext context = event.getServletContext();
        Object services = context.getAttribute(DataViewerServiceRegistry.SERVICES_ATTRIBUTE);
        if (services instanceof AutoCloseable) {
            try {
                ((AutoCloseable) services).close();
            } catch (Exception exception) {
                /* best effort shutdown */
            }
        }
        context.removeAttribute(DataViewerServiceRegistry.SERVICES_ATTRIBUTE);
        context.removeAttribute(DataViewerServiceRegistry.JSON_CODEC_ATTRIBUTE);
    }

    protected abstract DataViewerServices createServices(ServletContext context);
}
