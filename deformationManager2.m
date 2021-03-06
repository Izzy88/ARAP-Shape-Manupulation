%%Deformation manager for normal(vertices) coordinates%%
%This function manages CP creation, movement and cancellation. It also
%handles the whole deformation and mesh update system.
%CP = Control Point
%handles.handlesCoordinates --> matrix - coordinates of the CPs
%handles.linkedTriangle --> matrix - for each CP stores the id of the
%	edge that contains the linked vertex
%handles.cp --> row id for the selected CP in
%   handles.handlesCoordinates and handles.linkedTriangle
%handles.F --> matrix - list of triangles in the mesh. For each triangle we
%   have a list of ids of its vertices
%handles.V --> matrix - list of vertices
%handles.E --> matrix - list of edges. For each edge we have a list of 
%   ids of its vertices
%handles.G --> matrix - edges neighbors
%VPrime --> vertices coordinates after the First Step
%handles.T --> matrix - rotation matrix
function deformationManager2(hObject)
handles = guidata(hObject);

plotMesh(hObject,handles);

%Get the first N points selected by the user
try
  [Cx,Cy] = getpts;
catch e
  return
end
handles.handlesCoordinates = [Cx(1:size(Cx,1)-1,:),Cy(1:size(Cy,1)-1,:)];
handles.linkedTriangle = zeros(size(handles.handlesCoordinates,1),2);

%plot the N control points and wait for an action
hold all;
scatter(handles.handlesCoordinates(:,1),handles.handlesCoordinates(:,2),50,...
    'MarkerEdgeColor','k','MarkerFaceColor','r','ButtonDownFcn',@oncontrolsdown);
hold off;
drawnow

%%When the pointer clicks on a CP...
function oncontrolsdown(src,ev)
    %read and store the coordinates of the selected handle
    handles.down_pos = get(gca,'CurrentPoint');
    handles.down_pos = [handles.down_pos(1,1,1) handles.down_pos(1,2,1)];
    handles.last_drag_pos = handles.down_pos;
    handles.drag_pos = handles.down_pos;
    
    %link the control point with the closest vertex in the mesh and returns
    %the CP id
    guidata(hObject,handles);
    handles.linkedTriangle = linkTriangles2(hObject);
    handles.cp = getClosestCP(hObject);
    
    %'normal' for left click and 'alt' for right (or mid) click and 'open' for double click
    mouseButton = get(gcf,'SelectionType');

    %if 'alt' delete the selected CP
    if strcmp(mouseButton,'alt')
        handles.handlesCoordinates(handles.cp,:) = [];
        handles.linkedTriangle(handles.cp,:) = [];       
    end
  
    guidata(hObject,handles);
    % tell window that drag and up events should be handled by controls
    set(gcf,'windowbuttonmotionfcn',@oncontrolsdrag)
    set(gcf,'windowbuttonupfcn',@oncontrolsup)
end

%%While the CP is dragged...
function oncontrolsdrag(src,ev)
    handles.last_drag_pos = handles.drag_pos;
    %get current mouse position and store it
    delete(findobj(gca, 'type', 'scatter'));
    handles.drag_pos=get(gca,'CurrentPoint');
    handles.drag_pos=[handles.drag_pos(1,1,1) handles.drag_pos(1,2,1)];
    handles.handlesCoordinates(handles.cp,1) = handles.drag_pos(1,1);
    handles.handlesCoordinates(handles.cp,2) = handles.drag_pos(1,2);
    guidata(hObject, handles);
 
    %plot deformed mesh
    updateMesh(hObject,handles);

    %display CPs
    hold all
    scatter(handles.handlesCoordinates(:,1),handles.handlesCoordinates(:,2),50,...
        'MarkerEdgeColor','k','MarkerFaceColor','r');
    hold off
    drawnow
    guidata(hObject,handles);
end

%%When the CP is released
function oncontrolsup(src,ev)
    %allow window to manage drag and up events 
    set(gcf,'windowbuttonmotionfcn','');
    set(gcf,'windowbuttonupfcn','');
    guidata(hObject,handles);
    %idle
    writeMesh(hObject);
    waitForInput(hObject, handles);
end

%%When the pointer clicks on the mesh surface but not on a CP we add a new CP
function oncontrolsdownMesh (src,ev)
    handles.down_pos = get(gca,'CurrentPoint');
    handles.down_pos = [handles.down_pos(1,1,1) handles.down_pos(1,2,1)];
    %prepare the structures for the new CP
    handles.handlesCoordinates = [handles.handlesCoordinates;handles.down_pos(1,1),handles.down_pos(1,2)];
    handles.linkedTriangle = [handles.linkedTriangle;0,0];
    linkTriangles(hObject);
    
    %display all the CP
    hold all
    scatter(handles.handlesCoordinates(size(handles.handlesCoordinates,1),1),...
        handles.handlesCoordinates(size(handles.handlesCoordinates,1),2),50,...
        'MarkerEdgeColor','k','MarkerFaceColor','r','ButtonDownFcn',@oncontrolsdown);
    hold off
    drawnow   
    
    guidata(hObject,handles);
    set(gcf,'windowbuttonupfcn',@oncontrolsup)
end

%%When nothing is being clicked...
function waitForInput (hObject,handles)
    guidata(hObject,handles);
    %update the CP
    delete(findobj(gca, 'type', 'scatter'));
    hold all
    scatter(handles.handlesCoordinates(:,1),handles.handlesCoordinates(:,2),50,...
        'MarkerEdgeColor','k','MarkerFaceColor','r','ButtonDownFcn',@oncontrolsdown);
    hold off
    drawnow
end

function updateMesh (hObject,handles)
    %fisrt step: similarity transformation
    [handles.G, GIndeces] = computeG(handles.V, handles.E, handles.F);
    
    VPrime = buildRotationLinearSystem2(GIndeces, handles.G, handles.V, handles.E, handles.F,...
        handles.handlesCoordinates,handles.linkedTriangle);
    
    %second step: scale adjustment
    handles.T = computeRotationMatrix(VPrime, handles.G, GIndeces);
    
    %solving X and Y for the second step
    % coordID = 1 for X and  = 2 for Y
    [A, b] = buildLinearSystem2(1, handles.E, handles.handlesCoordinates, handles.V, handles.linkedTriangle,...
        handles.T);
    Vx = (A' * A) \ (A' * b); %solve linear system for x
    [A, b] = buildLinearSystem2(2, handles.E, handles.handlesCoordinates, handles.V, handles.linkedTriangle,...
        handles.T);
    Vy = (A' * A) \ (A' * b); %solve linear system for y
    
    %fill handles.V with the new coordinates
    handles.V = [Vx,Vy];
    
    %display the result
    plotMesh(hObject,handles);
end

%Display the mesh
function plotMesh(hObject,handles)   
    plot = trisurf(handles.F, handles.V(:,1), handles.V(:,2), zeros(size(handles.V,1),1),...
        'FaceColor','interp','ButtonDownFcn',@oncontrolsdownMesh);

    %2D view
    view(2);
    axis off
    hold on

    %set the windows size
    set(gca,'xlim',[-2 2],'ylim',[-1.5 2],'zlim',[0 1]);
    set(plot,'Parent', handles.axes1);
end

end