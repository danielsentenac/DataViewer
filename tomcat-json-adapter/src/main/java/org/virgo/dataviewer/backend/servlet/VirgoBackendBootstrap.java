package org.virgo.dataviewer.backend.servlet;

import javax.servlet.ServletContext;
import javax.servlet.annotation.WebListener;

import org.virgo.dataviewer.adapter.service.DataViewerServices;
import org.virgo.dataviewer.adapter.servlet.DataViewerServicesContextListener;
import org.virgo.dataviewer.backend.config.BackendConfig;
import org.virgo.dataviewer.backend.service.VirgoTomcatServices;

@WebListener
public final class VirgoBackendBootstrap extends DataViewerServicesContextListener {
    @Override
    protected DataViewerServices createServices(ServletContext context) {
        return new VirgoTomcatServices(BackendConfig.from(context));
    }
}
