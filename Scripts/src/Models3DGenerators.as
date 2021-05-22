/*
  Change texture coords to new texture coords.
*/        
Model@ CreateModelPlane(uint horizSeqment, uint verticalSeqment)
{

    Model@ modelPlane = Model();
    VertexBuffer@ vb = VertexBuffer();
    IndexBuffer@ ib  = IndexBuffer();
    Geometry@ geom   = Geometry();

    // Shadowed buffer needed for raycasts to work, and so that data can be automatically restored on device loss
    vb.shadowed = true;
    // We could use the "legacy" element bitmask to define elements for more compact code, but let's demonstrate
    // defining the vertex elements explicitly to allow any element types and order
    Array<VertexElement> elements;
    elements.Push(VertexElement(TYPE_VECTOR3, SEM_POSITION));
    elements.Push(VertexElement(TYPE_VECTOR2, SEM_TEXCOORD));
    vb.SetSize((verticalSeqment + 1) * (horizSeqment + 1), elements);

    uint horizVertexNumber = horizSeqment + 1;

    VectorBuffer vertexBuffer;
    for (uint y = 0; y <= verticalSeqment; y++)
    {
        for (uint x = 0; x < horizVertexNumber ; x++)
        {
            Vector3 v = Vector3(2.0 * float(x) / horizSeqment - 1.0, 2.0 * (float(y) / verticalSeqment) - 1.0, 0);
            // Vertex
            vertexBuffer.WriteVector3(v);
            // Texture Coords
            Vector2 tc = Vector2(float(x) / horizSeqment, 1.0 - float(y) / verticalSeqment);
            vertexBuffer.WriteVector2(tc);

//            Print("(" + v.x + " " + v.y + " " + v.z + ") " + " (" + tc.x + " " + tc.y + ")");
        }
    }
    vb.SetData(vertexBuffer);

    ib.shadowed = true;
    uint  indexNumbers = horizSeqment * verticalSeqment * 6;
    ib.SetSize(indexNumbers,  false);

    VectorBuffer indexBuffer;
    for (uint y = 0; y < verticalSeqment; y++)
    {
        for (uint x = 0; x < horizSeqment; x++)
        {
//            Print(y * horizVertexNumber + x + 1);
            indexBuffer.WriteUShort(y * horizVertexNumber + x + 1);
            //            Print(y * horizVertexNumber + x);
            indexBuffer.WriteUShort(y * horizVertexNumber + x);
            //            Print((y + 1) * horizVertexNumber + x);
            indexBuffer.WriteUShort((y + 1) * horizVertexNumber + x);



//            Print(y * horizVertexNumber + x + 1);
            indexBuffer.WriteUShort(y * horizVertexNumber + x + 1);
            //            Print((y + 1) * horizVertexNumber + x);
            indexBuffer.WriteUShort((y + 1) * horizVertexNumber + x);
//            Print((y + 1) * horizVertexNumber + x + 1);
            indexBuffer.WriteUShort((y + 1) * horizVertexNumber + x + 1);
        }
    }
    ib.SetData(indexBuffer);

    geom.SetVertexBuffer(0, vb);
    geom.SetIndexBuffer(ib);
    geom.SetDrawRange(TRIANGLE_LIST, 0, indexNumbers);

    modelPlane.numGeometries = 1;
    modelPlane.SetGeometry(0, 0, geom);
    modelPlane.boundingBox = BoundingBox(Vector3(-1, -1, -1), Vector3(1, 1, 1));

    return modelPlane;
}
